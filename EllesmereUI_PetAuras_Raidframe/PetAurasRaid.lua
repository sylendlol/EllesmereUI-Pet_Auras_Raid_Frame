if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUI_PetAuras_Raidframe \ PetAurasRaid.lua   (standalone add-on)
--
--  Buffs and debuffs on the Raid Frames RAID pet frames (the pet header's
--  buttons, up to 40, while the raid frames are on screen). The party pet
--  frames are EllesmereUI_PetAuras_Partyframe's. No EllesmereUI file is
--  modified.
--
--  * The client draws the auras itself (AuraContainer +
--    CustomAuraContainerTemplate), combat and secret auras included; the
--    add-on never reads aura data.
--  * One container per group per pet button, parented to the button, so it
--    follows every re-sort. The container's unit follows the button's unit
--    attribute (SetUnit is combat-legal, the Raid Frames do the same).
--  * Layout / style writes happen out of combat only (deferred to combat end).
--  * Move mode: 3 placeholder auras per group on the pet frames (real pets
--    and the options preview pets), draggable to set the X / Y offset.
--
--  Settings live in the Raid Frames profile: db.profile.petFrames.raidAuras
--  (so they follow EllesmereUI profiles).
-------------------------------------------------------------------------------
local EllesmereUI = _G.EllesmereUI
local RF = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIRaidFrames"]
local PF = RF and RF._PF
if not PF then return end

local floor, max, min = math.floor, math.max, math.min
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame

local PA = { recs = {}, byFrame = {}, move = false }
RF._PARF = PA

-- Two aura groups per container, both declared at creation: candidate filters are
-- declaration-fixed (a live SetAuraGroupCandidateFilters does not retake), so
-- "Show Permanent Auras" switches between them by max frame count (0 / max).
--   GK       : every aura
--   GK_TIMED : candidate maxDuration = huge -> the client drops duration-0 (permanent) auras
local GK = "main"
local GK_TIMED = "timed"
local NO_UNIT = "none"

local function Print(msg)
    print("|cff0cd29fPet Auras (Raid):|r " .. tostring(msg))
end
PA.Print = Print

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local DEFAULTS = {
    buffs = {
        enabled = true, position = "BOTTOMLEFT_IN", x = 1, y = 1,
        size = 12, spacing = 1, perRow = 3, max = 3, border = 1,
        showTimer = true, timerSize = 8, timerFont = "__global", timerOutline = "outline",
        timerPoint = "CENTER", timerX = 0, timerY = 0,
        countSize = 8, onlyMine = false, showPermanent = true,
    },
    debuffs = {
        enabled = true, position = "BOTTOMRIGHT_IN", x = -1, y = 1,
        size = 14, spacing = 1, perRow = 2, max = 2, border = 1,
        showTimer = true, timerSize = 8, timerFont = "__global", timerOutline = "outline",
        timerPoint = "CENTER", timerX = 0, timerY = 0,
        countSize = 8, onlyDispellable = false, showPermanent = true,
    },
}
PA.DEFAULTS = DEFAULTS
PA.GROUP_KEYS = { "buffs", "debuffs" }

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v end
    end
end

-- The settings table (created in the Raid Frames profile on first use), or nil
-- before the Raid Frames database is up.
function PA.Settings()
    local raw = PF.Raw()
    if not raw then return nil end
    local t = raw.raidAuras
    if type(t) ~= "table" then t = {}; raw.raidAuras = t end
    for _, k in ipairs(PA.GROUP_KEYS) do
        if type(t[k]) ~= "table" then t[k] = {} end
        CopyDefaults(DEFAULTS[k], t[k])
    end
    return t
end

function PA.ResetSettings()
    local raw = PF.Raw()
    if raw then raw.raidAuras = nil end
    PA.Apply()
end

-------------------------------------------------------------------------------
--  Positions: point on the block (= the flow corner), point on the pet frame,
--  horizontal growth (1 right / -1 left), row growth (1 up / -1 down).
-------------------------------------------------------------------------------
local POS = {
    TOPLEFT_OUT     = { b = "BOTTOMLEFT",  t = "TOPLEFT",     gx =  1, gy =  1 },
    TOPRIGHT_OUT    = { b = "BOTTOMRIGHT", t = "TOPRIGHT",    gx = -1, gy =  1 },
    BOTTOMLEFT_OUT  = { b = "TOPLEFT",     t = "BOTTOMLEFT",  gx =  1, gy = -1 },
    BOTTOMRIGHT_OUT = { b = "TOPRIGHT",    t = "BOTTOMRIGHT", gx = -1, gy = -1 },
    LEFT_OUT        = { b = "TOPRIGHT",    t = "TOPLEFT",     gx = -1, gy = -1 },
    RIGHT_OUT       = { b = "TOPLEFT",     t = "TOPRIGHT",    gx =  1, gy = -1 },
    TOPLEFT_IN      = { b = "TOPLEFT",     t = "TOPLEFT",     gx =  1, gy = -1 },
    TOPRIGHT_IN     = { b = "TOPRIGHT",    t = "TOPRIGHT",    gx = -1, gy = -1 },
    BOTTOMLEFT_IN   = { b = "BOTTOMLEFT",  t = "BOTTOMLEFT",  gx =  1, gy =  1 },
    BOTTOMRIGHT_IN  = { b = "BOTTOMRIGHT", t = "BOTTOMRIGHT", gx = -1, gy =  1 },
}
PA.POSITIONS = {
    TOPLEFT_OUT = "Above, Left", TOPRIGHT_OUT = "Above, Right",
    BOTTOMLEFT_OUT = "Below, Left", BOTTOMRIGHT_OUT = "Below, Right",
    LEFT_OUT = "Left Side", RIGHT_OUT = "Right Side",
    TOPLEFT_IN = "Inside Top Left", TOPRIGHT_IN = "Inside Top Right",
    BOTTOMLEFT_IN = "Inside Bottom Left", BOTTOMRIGHT_IN = "Inside Bottom Right",
}
PA.POSITION_ORDER = {
    "TOPLEFT_OUT", "TOPRIGHT_OUT", "BOTTOMLEFT_OUT", "BOTTOMRIGHT_OUT", "LEFT_OUT", "RIGHT_OUT",
    "---", "TOPLEFT_IN", "TOPRIGHT_IN", "BOTTOMLEFT_IN", "BOTTOMRIGHT_IN",
}

local function PosOf(s)
    return POS[s.position] or POS[DEFAULTS.buffs.position]
end

-------------------------------------------------------------------------------
--  Fonts (EllesmereUI font keys; "__global" = the Raid Frames font)
-------------------------------------------------------------------------------
local function TimerFont(s)
    local path
    if not s.timerFont or s.timerFont == "__global" then
        path = EllesmereUI.GetFontPath("raidFrames")
    else
        path = EllesmereUI.ResolveFontName(s.timerFont)
    end
    local flag
    if s.timerOutline == "__global" then
        flag = EllesmereUI.GetFontOutlineFlag("raidFrames")
    else
        flag = EllesmereUI.OutlineFlagForMode(s.timerOutline or "outline")
    end
    return path or STANDARD_TEXT_FONT, flag or ""
end

local function SetFontSafe(fs, path, size, flag)
    if not fs:SetFont(path, size, flag) then
        fs:SetFont(STANDARD_TEXT_FONT, size, EllesmereUI.StripSlugFlag and EllesmereUI.StripSlugFlag(flag) or "")
    end
    if flag == "" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function StyleTimer(cd, s)
    cd:SetHideCountdownNumbers(not s.showTimer)
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if not fs then return end
    local path, flag = TimerFont(s)
    SetFontSafe(fs, path, s.timerSize or 9, flag)
    fs:ClearAllPoints()
    local p = s.timerPoint or "CENTER"
    fs:SetPoint(p, cd, p, s.timerX or 0, s.timerY or 0)
end

local function StyleCount(fs, s)
    local path, flag = TimerFont(s)
    SetFontSafe(fs, path, s.countSize or 9, flag)
end

local function Inset(tex, parent, px)
    tex:ClearAllPoints()
    if PixelUtil then
        PixelUtil.SetPoint(tex, "TOPLEFT", parent, "TOPLEFT", px, -px)
        PixelUtil.SetPoint(tex, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", -px, px)
    else
        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", px, -px)
        tex:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -px, px)
    end
end

-------------------------------------------------------------------------------
--  Real aura buttons (the client calls this once per button it creates)
-------------------------------------------------------------------------------
local function HasAuraContainer()
    return AnchorUtil and AnchorUtil.FlowDirection and CustomAuraContainerGroupDefaultOptions ~= nil
end

local DISPEL_STYLE_PRESERVE =
    (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset) or 3

local function MakeInitializer(key)
    local isDebuff = key == "debuffs"
    return function(button)
        local S = PA.Settings()
        local s = (S and S[key]) or DEFAULTS[key]
        button:SetSize(s.size, s.size)
        -- Mouse-transparent: the pet frame under it keeps mouseover and click-casting.
        if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
        if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end

        local border = button:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)

        if isDebuff then
            local dispel = button:CreateTexture(nil, "BORDER")
            dispel:SetAllPoints()
            dispel:SetColorTexture(1, 1, 1, 1)
            button:AddDispelTypeTexture(dispel, {
                style = DISPEL_STYLE_PRESERVE,
                showWhenHarmful = true,
                showWithoutDispelType = true,
            })
        end

        local icon = button:CreateTexture(nil, "ARTWORK")
        Inset(icon, button, s.border or 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetIcon(icon)
        button.parfIcon = icon

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        StyleTimer(cd, s)
        button:SetDurationCooldown(cd)
        button.parfCooldown = cd

        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cd:GetFrameLevel() + 2)
        local count = overlay:CreateFontString(nil, "OVERLAY")
        count:SetPoint("BOTTOMRIGHT", 1, 0)
        StyleCount(count, s)
        button:SetApplicationCount(count)
        button.parfCount = count
    end
end

local function FilterFor(key, s)
    if key == "debuffs" then
        -- RAID_PLAYER_DISPELLABLE = what YOU can dispel (the Raid Frames' own token);
        -- plain RAID would mean "raid-relevant", not dispellable.
        return s.onlyDispellable and "HARMFUL|RAID_PLAYER_DISPELLABLE" or "HARMFUL"
    end
    return s.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
end

local function LayoutOptions(s)
    return { elementSpacing = s.spacing, lineSpacing = s.spacing, elementWidth = s.size, elementHeight = s.size }
end

local function SortArgs()
    local m = AuraContainerSortMethod and (AuraContainerSortMethod.AuraInstanceIDOnly or AuraContainerSortMethod.Default)
    local d = AuraContainerSortDirection and AuraContainerSortDirection.Normal
    return m, d
end

-------------------------------------------------------------------------------
--  Placeholder auras (move mode + options preview)
-------------------------------------------------------------------------------
-- { spellID, duration (0 = permanent), stacks, dispel type }
-- The first PH_COUNT matching entries are shown; with Show Permanent Auras off the
-- duration-0 ones are skipped.
local PLACEHOLDERS = {
    buffs   = { { 136, 15, 0 }, { 1126, 0, 0 }, { 21562, 0, 0 }, { 774, 12, 0 }, { 1022, 10, 0 } },
    debuffs = { { 589, 18, 0, "Magic" }, { 980, 24, 0, "Curse" }, { 26013, 0, 0, nil },
                { 2818, 12, 3, "Poison" }, { 118, 8, 0, "Magic" } },
}
local PH_COUNT = 3
local phList = { buffs = {}, debuffs = {} }

local function PlaceholderData(key, s)
    local out = phList[key]
    wipe(out)
    for _, d in ipairs(PLACEHOLDERS[key]) do
        if s.showPermanent ~= false or d[2] > 0 then
            out[#out + 1] = d
            if #out >= PH_COUNT then break end
        end
    end
    return out
end

local FALLBACK_DISPEL = {
    Magic = { 0.20, 0.60, 1.00 }, Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 }, Poison = { 0.00, 0.60, 0.00 }, None = { 0.80, 0.00, 0.00 },
}
local function DispelColor(dtype)
    if AuraUtil and AuraUtil.GetAuraBorderColor then
        local ok, c = pcall(AuraUtil.GetAuraBorderColor, dtype)
        if ok and c and c.GetRGB then return c:GetRGB() end
    end
    local c = FALLBACK_DISPEL[dtype or "None"] or FALLBACK_DISPEL.None
    return c[1], c[2], c[3]
end

local function SpellIcon(id)
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok then tex = t end
    end
    if not tex and GetSpellTexture then
        local ok, t = pcall(GetSpellTexture, id)
        if ok then tex = t end
    end
    return tex or 134400
end

local function PH_OnCooldownDone(self)
    if self.dur and self.dur > 0 and self:IsVisible() then self:SetCooldown(GetTime(), self.dur) end
end

local function GetPlaceholder(g, key, i)
    local b = g.ph[i]
    if b then return b end
    b = CreateFrame("Frame", nil, g.block)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.cd:SetReverse(true)
    b.cd:SetDrawEdge(false)
    b.cd:SetScript("OnCooldownDone", PH_OnCooldownDone)
    local ov = CreateFrame("Frame", nil, b)
    ov:SetAllPoints()
    ov:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.count = ov:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOMRIGHT", 1, 0)
    b:EnableMouse(false)
    b:Hide()
    g.ph[i] = b
    return b
end

-- Gives a placeholder its fake aura; a new one restarts its cooldown.
local function SetPlaceholderData(b, key, data)
    if b.data == data then return end
    b.data = data
    b.icon:SetTexture(SpellIcon(data[1]))
    b.cd.dur = data[2]
    b.stacks = data[3]
    if key == "debuffs" then
        b.border:SetColorTexture(DispelColor(data[4] or "None"))
    else
        b.border:SetColorTexture(0, 0, 0, 1)
    end
    b:Hide()
end

local function LayoutPlaceholders(g, key, s, show)
    local list = PlaceholderData(key, s)
    local n = show and min(#list, s.max) or 0
    local P = PosOf(s)
    local step = s.size + s.spacing
    for i = 1, n do
        local b = GetPlaceholder(g, key, i)
        SetPlaceholderData(b, key, list[i])
        local col = (i - 1) % s.perRow
        local row = floor((i - 1) / s.perRow)
        b:SetSize(s.size, s.size)
        b:ClearAllPoints()
        b:SetPoint(P.b, g.block, P.b, col * step * P.gx, row * step * P.gy)
        Inset(b.icon, b, s.border or 1)
        StyleTimer(b.cd, s)
        StyleCount(b.count, s)
        b.count:SetText((b.stacks or 0) > 1 and b.stacks or "")
        if not b:IsShown() then
            b:Show()
            if b.cd.dur > 0 then
                b.cd:SetCooldown(GetTime() - (i * 2.3) % b.cd.dur, b.cd.dur)
            else
                b.cd:Clear()
            end
        end
    end
    for i = n + 1, #g.ph do g.ph[i]:Hide() end
end

-------------------------------------------------------------------------------
--  Drag (move mode): our own mouse frame over each block, so nothing secure
--  ever takes mouse changes. Offsets are in the pet frame's own units.
-------------------------------------------------------------------------------
local function Accent()
    local a = EllesmereUI.ELLESMERE_GREEN
    if type(a) == "table" then return a.r or a[1] or 0.05, a.g or a[2] or 0.82, a.b or a[3] or 0.62 end
    return 0.05, 0.82, 0.62
end

local function Grab_OnUpdate(self)
    local d = self.drag
    if not d then return end
    local S = PA.Settings()
    if not S then return end
    local s = S[self.key]
    local x, y = GetCursorPosition()
    local nx = floor(d.sx + (x - d.cx) / d.scale + 0.5)
    local ny = floor(d.sy + (y - d.cy) / d.scale + 0.5)
    if nx ~= s.x or ny ~= s.y then
        s.x, s.y = nx, ny
        PA.PlaceBlocks(self.key)
    end
end

local function Grab_OnMouseDown(self, button)
    if button ~= "LeftButton" or InCombatLockdown() then return end
    local S = PA.Settings()
    if not S then return end
    local s = S[self.key]
    local x, y = GetCursorPosition()
    self.drag = { cx = x, cy = y, sx = s.x or 0, sy = s.y or 0, scale = self:GetEffectiveScale() }
    self:SetScript("OnUpdate", Grab_OnUpdate)
end

local function Grab_OnMouseUp(self)
    if not self.drag then return end
    self.drag = nil
    self:SetScript("OnUpdate", nil)
    PA.Apply()
    PA.RefreshOptionWidgets()
end

local function Grab_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.key == "debuffs" and "Pet Debuffs" or "Pet Buffs")
    GameTooltip:AddLine("Drag to move. Right-click: reset offset.", 1, 1, 1)
    GameTooltip:Show()
end

local function Grab_OnClick(self, button)
    if button == "RightButton" and not InCombatLockdown() then
        local S = PA.Settings()
        if not S then return end
        local s = S[self.key]
        s.x, s.y = DEFAULTS[self.key].x, DEFAULTS[self.key].y
        PA.Apply()
        PA.RefreshOptionWidgets()
    end
end

local function MakeGrab(g, key)
    local grab = CreateFrame("Frame", nil, g.block)
    grab:SetPoint("TOPLEFT", g.block, "TOPLEFT", -1, 1)
    grab:SetPoint("BOTTOMRIGHT", g.block, "BOTTOMRIGHT", 1, -1)
    grab:SetFrameLevel(g.block:GetFrameLevel() + 20)
    grab.key = key
    grab.bg = grab:CreateTexture(nil, "BACKGROUND")
    grab.bg:SetAllPoints()
    grab:EnableMouse(true)
    grab:SetScript("OnMouseDown", Grab_OnMouseDown)
    grab:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then Grab_OnClick(self, button) else Grab_OnMouseUp(self) end
    end)
    grab:SetScript("OnEnter", Grab_OnEnter)
    grab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grab:SetScript("OnHide", function(self)
        if self.drag then self.drag = nil; self:SetScript("OnUpdate", nil) end
    end)
    grab:Hide()
    g.grab = grab
end

local function PaintGrab(grab, key)
    if key == "debuffs" then
        grab.bg:SetColorTexture(1, 0.2, 0.2, 0.30)
    else
        local r, g, b = Accent()
        grab.bg:SetColorTexture(r, g, b, 0.30)
    end
end

-------------------------------------------------------------------------------
--  Records: one per pet frame (real button or options preview pet)
-------------------------------------------------------------------------------
local function UpdateAll(c)
    if c and c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
end

local function Bind(rec, unit)
    unit = unit or NO_UNIT
    if rec.unit == unit then return end
    rec.unit = unit
    for _, g in pairs(rec.groups) do
        if g.container then
            g.container:SetUnit(unit)
            UpdateAll(g.container)
        end
    end
end

-- real: a secure pet button (OOC only: creates containers). kind: "owner" / "header" / "preview".
local function NewRec(target, kind)
    local real = kind ~= "preview"
    local rec = { target = target, kind = kind, real = real, groups = {} }
    local holder = CreateFrame("Frame", nil, target)
    holder:SetAllPoints(target)
    holder:SetFrameLevel(target:GetFrameLevel() + 6)
    rec.holder = holder
    for _, key in ipairs(PA.GROUP_KEYS) do
        local g = { ph = {} }
        g.block = CreateFrame("Frame", nil, holder)
        g.block:SetSize(1, 1)
        g.block:SetPoint("CENTER", target, "CENTER")
        g.block:EnableMouse(false)
        MakeGrab(g, key)
        if real then
            local S = PA.Settings()
            local s = (S and S[key]) or DEFAULTS[key]
            local c = CreateFrame("AuraContainer", nil, g.block, "CustomAuraContainerTemplate")
            local m, d = SortArgs()
            local perm = s.showPermanent ~= false
            c:AddAuraGroup(GK, FilterFor(key, s), {
                sortMethod = m, sortDirection = d,
                maxFrameCount = perm and s.max or 0,
                initializeFrame = MakeInitializer(key),
                layout = LayoutOptions(s),
            })
            c:AddAuraGroup(GK_TIMED, FilterFor(key, s), {
                sortMethod = m, sortDirection = d,
                maxFrameCount = perm and 0 or s.max,
                candidateFilters = { maxDuration = math.huge },
                initializeFrame = MakeInitializer(key),
                layout = LayoutOptions(s),
            })
            c:SetUnit(NO_UNIT)
            g.container = c
        end
        rec.groups[key] = g
    end
    PA.recs[#PA.recs + 1] = rec
    PA.byFrame[target] = rec
    if real then
        Bind(rec, target:GetAttribute("unit"))
        target:HookScript("OnAttributeChanged", function(self, name, value)
            if name == "unit" then Bind(rec, value) end
        end)
    end
    return rec
end

-- The pet header also runs the party pets: auras here only while the raid frames are up.
local function RecOn(rec)
    if rec.kind == "header" then return PF.Ctx() == "raid" end
    if rec.kind == "preview" then return rec.raid == true end
    return false
end

local function PlaceBlock(g, target, s)
    local P = PosOf(s)
    local lineW = s.perRow * s.size + (s.perRow - 1) * s.spacing
    g.block:SetSize(max(1, lineW), max(1, s.size))
    g.block:ClearAllPoints()
    g.block:SetPoint(P.b, target, P.t, s.x or 0, s.y or 0)
    return P, lineW
end

-- Existing real aura buttons (the client may refuse writes outside their creation window).
local function RestyleExisting(c, s, gk)
    local n = c:GetAuraGroupFrameCount(gk)
    for i = 1, n do
        local b = c:GetAuraGroupFrame(gk, i)
        if b then
            b:SetSize(s.size, s.size)
            if b.parfIcon then Inset(b.parfIcon, b, s.border or 1) end
            if b.parfCooldown then StyleTimer(b.parfCooldown, s) end
            if b.parfCount then StyleCount(b.parfCount, s) end
        end
    end
end

local function ApplyRealGroup(rec, key, g, s, on)
    local P, lineW = PlaceBlock(g, rec.target, s)
    local c = g.container
    if c then
        local FD = AnchorUtil.FlowDirection
        c:ClearAllPoints()
        c:SetPoint(P.b, g.block, P.b, 0, 0)
        c:SetFlowLayoutAnchorPoint(P.b)
        c:SetFlowLayoutGrowthDirection(P.gx > 0 and FD.Right or FD.Left, P.gy > 0 and FD.Up or FD.Down)
        c:SetFlowLayoutMaximumLineSize(lineW + 0.5)
        local perm = s.showPermanent ~= false
        local filter, layout = FilterFor(key, s), LayoutOptions(s)
        for _, gk in ipairs({ GK, GK_TIMED }) do
            c:SetAuraGroupFilterString(gk, filter)
            c:SetAuraGroupLayout(gk, layout)
        end
        c:SetAuraGroupMaxFrameCount(GK, perm and s.max or 0)
        c:SetAuraGroupMaxFrameCount(GK_TIMED, perm and 0 or s.max)
        c:SetEnabled(on)
        c:SetShown(on and not PA.move)
        pcall(RestyleExisting, c, s, GK)
        pcall(RestyleExisting, c, s, GK_TIMED)
    end
end

local function ApplyRec(rec, S)
    local on = RecOn(rec)
    if rec.real then
        if InCombatLockdown() then
            -- Only alpha is safe in combat; the full apply runs at combat end.
            rec.holder:SetAlpha(on and 1 or 0)
            PA.pending = true
            return
        end
        rec.holder:SetAlpha(1)
        rec.holder:SetShown(on)
    end
    for _, key in ipairs(PA.GROUP_KEYS) do
        local s, g = S[key], rec.groups[key]
        local gon = on and s.enabled
        if rec.real then
            local ok, err = pcall(ApplyRealGroup, rec, key, g, s, gon)
            if not ok and not PA.errShown then PA.errShown = true; Print("Error: " .. tostring(err)) end
        else
            PlaceBlock(g, rec.target, s)
        end
        -- Placeholders: always on the options preview pets, on the real pets only in move mode.
        local ph = gon and (PA.move or not rec.real)
        LayoutPlaceholders(g, key, s, ph)
        if gon and PA.move then
            PaintGrab(g.grab, key)
            g.grab:Show()
        else
            g.grab:Hide()
        end
    end
end

function PA.ApplyNow()
    local S = PA.Settings()
    if not S then return end
    if PA.move and InCombatLockdown() then PA.SetMove(false) return end
    for i = 1, #PA.recs do ApplyRec(PA.recs[i], S) end
end

-- Coalesced: at most once per frame (sliders, drags).
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
    self:Hide()
    PA.ApplyNow()
end)
function PA.Apply()
    driver:Show()
end

-- Drag: only re-anchor the blocks of one group (cheap, every frame).
function PA.PlaceBlocks(key)
    local S = PA.Settings()
    if not S or InCombatLockdown() then return end
    local s = S[key]
    for i = 1, #PA.recs do
        local rec = PA.recs[i]
        PlaceBlock(rec.groups[key], rec.target, s)
    end
end

function PA.RefreshOptionWidgets()
    local rl = EllesmereUI._widgetRefreshList
    if rl then for i = 1, #rl do pcall(rl[i]) end end
end

-------------------------------------------------------------------------------
--  Finding the pet buttons (they are made lazily by the Raid Frames)
-------------------------------------------------------------------------------
function PA.Sync()
    if not PA.ok then return end
    if InCombatLockdown() then PA.pending = true return end
    PA.pending = nil
    for _, b in ipairs(PF.buttons) do
        if not PA.byFrame[b] then NewRec(b, "header") end
    end
    PA.lastCtx = PF.Ctx()
    PA.ApplyNow()
end

-- Options preview pets (plain frames). raid: whether this pass is the Raid tab's preview.
local function DecoratePreview(raid)
    if not PA.ok then return end
    local S = PA.Settings()
    if not S then return end
    for i = 1, #PF.pv do
        local f = PF.pv[i]
        local rec = PA.byFrame[f] or NewRec(f, "preview")
        rec.raid = raid
        ApplyRec(rec, S)
    end
end

-------------------------------------------------------------------------------
--  Move mode
-------------------------------------------------------------------------------
function PA.IsMoving() return PA.move end

function PA.SetMove(state)
    state = state and true or false
    if state and InCombatLockdown() then
        Print("Move mode is not available in combat.")
        return
    end
    if PA.move == state then return end
    PA.move = state
    if state then PA.Sync() end
    PA.ApplyNow()
    PA.RefreshOptionWidgets()
end

-------------------------------------------------------------------------------
--  Hooks + events
-------------------------------------------------------------------------------
local function OnPetChanged(owner)
    local pt = owner and PF.PET_OF[owner]
    if not pt then return end
    for i = 1, #PA.recs do
        local rec = PA.recs[i]
        if rec.real and rec.unit == pt then
            for _, g in pairs(rec.groups) do UpdateAll(g.container) end
        end
    end
end

-- Roster changes can hand a pet token to a different pet without a unit attribute
-- change; one coalesced re-read of the visible containers covers it.
local function RefreshVisible()
    PA.refreshQueued = nil
    for i = 1, #PA.recs do
        local rec = PA.recs[i]
        if rec.real and rec.target:IsVisible() then
            for _, g in pairs(rec.groups) do UpdateAll(g.container) end
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if not HasAuraContainer() then
            Print("This client has no AuraContainer system; the add-on is disabled.")
            return
        end
        PA.ok = true
        hooksecurefunc(RF, "PF_Apply", PA.Sync)
        hooksecurefunc(RF, "PF_ShowOwnerPreview", function() DecoratePreview(false) end)
        hooksecurefunc(RF, "PF_ShowPreview", function(_, s)
            DecoratePreview(s ~= nil and s ~= RF._scaledPartyProxy)
        end)
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        ev:RegisterEvent("PLAYER_REGEN_DISABLED")
        ev:RegisterEvent("GROUP_ROSTER_UPDATE")
        -- Raid owners: up to 40 units, more than RegisterUnitEvent takes.
        ev:RegisterEvent("UNIT_PET")
        ev:RegisterEvent("UNIT_ENTERED_VEHICLE")
        ev:RegisterEvent("UNIT_EXITED_VEHICLE")
        C_Timer.After(1, PA.Sync)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if PA.move then PA.SetMove(false) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if PA.pending then PA.Sync() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Only a party <-> raid flip changes what shows (the header re-units its own buttons).
        local ctx = PF.Ctx()
        if ctx ~= PA.lastCtx then
            PA.lastCtx = ctx
            PA.Apply()
        end
        if not PA.refreshQueued then
            PA.refreshQueued = true
            C_Timer.After(0.3, RefreshVisible)
        end
    else -- UNIT_PET / vehicle
        OnPetChanged(arg1)
    end
end)

-------------------------------------------------------------------------------
--  Slash: /parf (move mode), /parf reset
-------------------------------------------------------------------------------
SLASH_EUIPETAURASRAID1 = "/parf"
SlashCmdList.EUIPETAURASRAID = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset" then
        PA.ResetSettings()
        Print("Settings reset to defaults.")
    elseif msg == "" or msg == "move" then
        PA.SetMove(not PA.move)
        Print(PA.move and "Move mode ON: drag the colored blocks on the pet frames (right-click resets). /parf again to lock."
            or "Move mode OFF.")
    else
        Print("/parf - toggle move mode,  /parf reset - default settings.  Options: Raid Frames > Raid tab > PET AURAS")
    end
end
