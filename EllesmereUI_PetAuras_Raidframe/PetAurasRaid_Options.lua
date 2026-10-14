if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUI_PetAuras_Raidframe \ PetAurasRaid_Options.lua
--
--  Raid Frames > Raid tab > PET AURAS, without touching EllesmereUI files:
--  ns.RFO_BuildVisualIndicators is wrapped. On the Raid tab, while Show Pets
--  is on, our section is inserted right before the EXTRAS header (that is,
--  right after PET FRAMES). The EXTRAS sync overlay is told to start below
--  our rows, so it never covers them.
-------------------------------------------------------------------------------
local EllesmereUI = _G.EllesmereUI
local RF = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIRaidFrames"]
local PA = RF and RF._PARF
if not PA then return end
local PF = RF._PF

local function RaidPetsOn()
    local raw = PF.Raw()
    return raw and raw.raid == true
end

-- "Move Auras" button, right-aligned in a DualRow half (same look as the Raid Frames' Move Frames).
local function MoveButton(row, rgn)
    if EllesmereUI._prebuilding then return end
    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(140, 26)
    btn:SetPoint("RIGHT", rgn, "RIGHT", -20, 0)
    btn:SetFrameLevel(row:GetFrameLevel() + 5)
    local bbg = btn:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    bbg:SetColorTexture(0.077, 0.068, 0.058, 0.92)
    if EllesmereUI.MakeBorder then EllesmereUI.MakeBorder(btn, 1, 1, 1, 0.25) end
    local lbl = btn:CreateFontString(nil, "OVERLAY")
    if EllesmereUI.ApplyModuleFont then
        EllesmereUI.ApplyModuleFont(lbl, nil, 13, "raidFrames")
    else
        lbl:SetFontObject(GameFontNormal)
    end
    lbl:SetPoint("CENTER")
    local function Update()
        lbl:SetText(PA.IsMoving() and "Stop Moving" or "Move Auras")
        btn:SetAlpha(InCombatLockdown() and 0.35 or 1)
    end
    btn:SetScript("OnEnter", function(self)
        if InCombatLockdown() then
            EllesmereUI.ShowWidgetTooltip(self, "Not available in combat")
        else
            EllesmereUI.ShowWidgetTooltip(self,
                "Shows placeholder auras on the pet frames (and on the preview). Drag a colored block to move it, right-click resets its offset, click again to lock.")
        end
    end)
    btn:SetScript("OnLeave", function() EllesmereUI.HideWidgetTooltip() end)
    btn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        PA.SetMove(not PA.IsMoving())
        Update()
    end)
    if EllesmereUI.RegisterWidgetRefresh then EllesmereUI.RegisterWidgetRefresh(Update) end
    Update()
    return btn
end

local OUTLINE_VALUES = {
    ["__global"] = { text = "EUI Global Default" },
    ["none"]     = { text = "Drop Shadow" },
    ["outline"]  = { text = "Outline" },
    ["thick"]    = { text = "Thick Outline" },
}
local OUTLINE_ORDER = { "__global", "none", "outline", "thick" }
local TIMER_POINTS = { TOP = "Top", CENTER = "Center", BOTTOM = "Bottom" }
local TIMER_POINT_ORDER = { "TOP", "CENTER", "BOTTOM" }

-- One group's rows (3 rows). Returns the new y.
local function BuildGroup(parent, y, W, key)
    local isDebuff = key == "debuffs"
    local Name = isDebuff and "Debuff" or "Buff"
    local _, h, row
    local function S() return PA.Settings()[key] end
    local function Set(k, v) S()[k] = v; PA.Apply() end
    local function off() return not S().enabled end
    local offTip = "Show Pet " .. Name .. "s"
    local fontValues, fontOrder
    if EllesmereUI.BuildFontDropdownData then
        fontValues, fontOrder = EllesmereUI.BuildFontDropdownData()
    else
        fontValues, fontOrder = { ["__global"] = { text = "EUI Global Font" } }, { "__global" }
    end

    -- Position (+cog: X, Y, Spacing) | Icon Size (+cog: Max, Per Row, Stack Size, filter)
    row, h = W:DualRow(parent, y,
        { type = "dropdown", text = Name .. " Position",
          tooltip = "Where the pet " .. Name:lower() .. "s sit on the pet frame. Fine-tune with the cog or by dragging in Move Auras.",
          values = PA.POSITIONS, order = PA.POSITION_ORDER,
          disabled = off, disabledTooltip = offTip,
          getValue = function() return S().position end,
          setValue = function(v)
              local s = S()
              s.position = v
              s.x, s.y = 0, 0
              PA.Apply()
              PA.RefreshOptionWidgets()
          end },
        { type = "slider", text = Name .. " Icon Size", min = 8, max = 40, step = 1,
          disabled = off, disabledTooltip = offTip,
          getValue = function() return S().size end,
          setValue = function(v) Set("size", v) end }
    ); y = y - h
    if not EllesmereUI._prebuilding and row and EllesmereUI.BuildInlineCog then
        EllesmereUI.BuildInlineCog(row._leftRegion, {
            disabled = off, disabledTooltip = offTip,
            title = "Pet " .. Name .. " Position",
            rows = {
                { type = "slider", label = "X Offset", min = -100, max = 100, step = 1,
                  get = function() return S().x or 0 end, set = function(v) Set("x", v) end },
                { type = "slider", label = "Y Offset", min = -100, max = 100, step = 1,
                  get = function() return S().y or 0 end, set = function(v) Set("y", v) end },
                { type = "slider", label = "Spacing", min = 0, max = 10, step = 1,
                  get = function() return S().spacing end, set = function(v) Set("spacing", v) end },
            },
        })
        local filterRow = isDebuff
            and { type = "toggle", label = "Only Dispellable",
                  get = function() return S().onlyDispellable == true end,
                  set = function(v) Set("onlyDispellable", v and true or false) end }
            or  { type = "toggle", label = "Only Mine",
                  get = function() return S().onlyMine == true end,
                  set = function(v) Set("onlyMine", v and true or false) end }
        EllesmereUI.BuildInlineCog(row._rightRegion, {
            disabled = off, disabledTooltip = offTip,
            title = "Pet " .. Name .. " Icons",
            rows = {
                { type = "slider", label = "Max Icons", min = 1, max = 16, step = 1,
                  get = function() return S().max end, set = function(v) Set("max", v) end },
                { type = "slider", label = "Icons Per Row", min = 1, max = 16, step = 1,
                  get = function() return S().perRow end, set = function(v) Set("perRow", v) end },
                { type = "slider", label = "Border", min = 0, max = 4, step = 1,
                  get = function() return S().border end, set = function(v) Set("border", v) end },
                { type = "slider", label = "Stack Text Size", min = 6, max = 24, step = 1,
                  get = function() return S().countSize end, set = function(v) Set("countSize", v) end },
                filterRow,
            },
        })
    end

    -- Show Timer (+cog: timer position) | Timer Size
    local function timerOff() return off() or not S().showTimer end
    row, h = W:DualRow(parent, y,
        { type = "toggle", text = Name .. " Timer",
          tooltip = "Remaining time on the " .. Name:lower() .. " icons.",
          disabled = off, disabledTooltip = offTip,
          getValue = function() return S().showTimer ~= false end,
          setValue = function(v) Set("showTimer", v and true or false); EllesmereUI:RefreshPage() end },
        { type = "slider", text = Name .. " Timer Size", min = 6, max = 24, step = 1,
          disabled = timerOff, disabledTooltip = Name .. " Timer",
          getValue = function() return S().timerSize end,
          setValue = function(v) Set("timerSize", v) end }
    ); y = y - h
    if not EllesmereUI._prebuilding and row and EllesmereUI.BuildInlineCog then
        EllesmereUI.BuildInlineCog(row._leftRegion, {
            disabled = timerOff, disabledTooltip = Name .. " Timer",
            title = "Pet " .. Name .. " Timer",
            rows = {
                { type = "dropdown", label = "Timer Position", values = TIMER_POINTS, order = TIMER_POINT_ORDER,
                  get = function() return S().timerPoint or "CENTER" end,
                  set = function(v) Set("timerPoint", v) end },
                { type = "slider", label = "Timer X", min = -20, max = 20, step = 1,
                  get = function() return S().timerX or 0 end, set = function(v) Set("timerX", v) end },
                { type = "slider", label = "Timer Y", min = -20, max = 20, step = 1,
                  get = function() return S().timerY or 0 end, set = function(v) Set("timerY", v) end },
            },
        })
    end

    -- Timer Font | Timer Outline (the stack count uses the same font)
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = Name .. " Timer Font",
          values = fontValues, order = fontOrder,
          disabled = off, disabledTooltip = offTip,
          getValue = function()
              local v = S().timerFont or "__global"
              if not fontValues[v] then v = "__global" end
              return v
          end,
          setValue = function(v) Set("timerFont", v) end },
        { type = "dropdown", text = Name .. " Timer Outline",
          values = OUTLINE_VALUES, order = OUTLINE_ORDER,
          disabled = off, disabledTooltip = offTip,
          getValue = function() return S().timerOutline or "outline" end,
          setValue = function(v) Set("timerOutline", v) end }
    ); y = y - h
    return y
end

-- The whole PET AURAS section. Returns the new y.
local function BuildSection(parent, y, W)
    local _, h, row
    _, h = W:SectionHeader(parent, "PET AURAS", y); y = y - h
    local function S(k) return PA.Settings()[k] end

    -- Show Pet Buffs | Show Pet Debuffs
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Show Pet Buffs",
          tooltip = "Buffs on the raid pet frames (the pets shown with the raid frames).",
          getValue = function() return S("buffs").enabled == true end,
          setValue = function(v) S("buffs").enabled = v and true or false; PA.Apply(); EllesmereUI:RefreshPage() end },
        { type = "toggle", text = "Show Pet Debuffs",
          tooltip = "Debuffs on the raid pet frames; the border shows the dispel type.",
          getValue = function() return S("debuffs").enabled == true end,
          setValue = function(v) S("debuffs").enabled = v and true or false; PA.Apply(); EllesmereUI:RefreshPage() end }
    ); y = y - h

    -- Show Auras Buff | Show Auras Debuff (auras with no duration)
    local function PermCfg(key, text, what)
        return { type = "toggle", text = text,
          tooltip = "Off: " .. what .. " with no duration (passives, paladin auras, toggles and other permanent effects) are hidden; only timed ones show.",
          disabled = function() return not S(key).enabled end,
          disabledTooltip = key == "debuffs" and "Show Pet Debuffs" or "Show Pet Buffs",
          getValue = function() return S(key).showPermanent ~= false end,
          setValue = function(v) S(key).showPermanent = v and true or false; PA.Apply() end }
    end
    _, h = W:DualRow(parent, y,
        PermCfg("buffs", "Show Auras Buff", "buffs"),
        PermCfg("debuffs", "Show Auras Debuff", "debuffs")
    ); y = y - h

    -- Move Auras
    row, h = W:DualRow(parent, y, { type = "label", text = "Aura Positions" }, EllesmereUI.BlankRowCfg()); y = y - h
    if row and row._leftRegion then MoveButton(row, row._leftRegion) end

    y = BuildGroup(parent, y, W, "buffs")
    y = BuildGroup(parent, y, W, "debuffs")
    return y
end

local function Install()
    if PA.optionsHooked then return true end
    local orig = RF.RFO_BuildVisualIndicators
    if type(orig) ~= "function" then return false end
    PA.optionsHooked = true
    -- Closing the settings window locks the placeholders again.
    if EllesmereUI.RegisterOnHide then
        EllesmereUI:RegisterOnHide(function()
            if PA.IsMoving() then PA.SetMove(false) end
        end)
    end

    RF.RFO_BuildVisualIndicators = function(parent, y, W, onSection, ...)
        local env = RF._RFO_OptEnv
        local party = env and env.optState and env.optState._partyCtx
        if party or type(W) ~= "table" or not RaidPetsOn() or not PA.Settings() then
            return orig(parent, y, W, onSection, ...)
        end
        local rawSH = rawget(W, "SectionHeader")
        local baseSH = W.SectionHeader
        local endY
        W.SectionHeader = function(self, p, text, yy, ...)
            if text == "EXTRAS" and not endY then
                W.SectionHeader = rawSH
                local ok, ny = pcall(BuildSection, p, yy, W)
                if ok and type(ny) == "number" then
                    endY = ny
                else
                    endY = yy
                    if not ok then geterrorhandler()(ny) end
                end
                local f, h = baseSH(self, p, text, endY, ...)
                return f, (h or 0) + (yy - endY)
            end
            return baseSH(self, p, text, yy, ...)
        end
        -- EXTRAS' sync overlay starts below our rows.
        local wrapped = onSection and function(key, s, e, ...)
            if key == "rangeTooltip" and endY then s = endY end
            return onSection(key, s, e, ...)
        end
        local ok, res = pcall(orig, parent, y, W, wrapped, ...)
        W.SectionHeader = rawSH
        if not ok then error(res, 0) end
        return res
    end
    return true
end

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if not (IsLoaded and IsLoaded("EllesmereUIOptions") and Install()) then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "EllesmereUIOptions" then
            Install()
            self:UnregisterAllEvents()
        end
    end)
end
