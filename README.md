# EllesmereUI-Pet_Auras_Raid_Frame
<img width="1304" height="948" alt="{E2D56874-7145-46E2-86FF-7DD929DE2F80}" src="https://github.com/user-attachments/assets/51d2a1f3-a4e6-4853-80ec-1da08a6ec8ab" />
<img width="766" height="387" alt="{7F6BAB19-462E-4618-A8B5-1C3346C44EE7}" src="https://github.com/user-attachments/assets/1aca5d83-977b-4b2b-910b-70c5320c65c4" />
<img width="315" height="195" alt="{0F4D8B9D-9B5D-4156-91D8-1A1E3603567F}" src="https://github.com/user-attachments/assets/13cb1bab-642d-4f2a-86fa-f47a8633a773" />

Buffs and debuffs on the **pet frames of EllesmereUI Raid Frames**: one add-on for the party pet frames, one for the raid pet frames. Buffs and debuffs are separate blocks that you position and style independently.

Both are standalone plugins for **EllesmereUI**. Neither modifies any EllesmereUI file.

| Add-on | Shows auras on | Settings | Slash |
|---|---|---|---|
| **EllesmereUI_PetAuras_Partyframe** | Party pet frames: *Beside Owner* pets, your own pet button, and the pet header while the party frames are shown | Raid Frames → **Party** → PET AURAS | `/papf` |
| **EllesmereUI_PetAuras_Raidframe** | Raid pet frames: the pet header (up to 40 pets) while the raid frames are shown | Raid Frames → **Raid** → PET AURAS | `/parf` |

You can install either one or both. They have separate settings and never show on the same frames at the same time.

---

## Features

- **Separate buff and debuff blocks.** Each one has its own on/off switch and position: above, below, left or right of the pet frame, or inside any corner. Fine-tune with X/Y offsets.
- **Move mode with placeholders.** Click **Move Auras** in the settings, or use the slash command, to show 3 placeholder auras per block on the pet frames and in the options preview. Drag a colored block to move it. Right-click a block to reset its offset.
- **Icons:** size, spacing, max icons, icons per row, border thickness, stack text size.
- **Timer:** on/off, size, position (top / center / bottom plus X/Y), font (any EllesmereUI or SharedMedia font; the default is the Raid Frames font), outline.
- **Filters:** *Only Mine* for buffs, *Only Dispellable* for debuffs (debuffs you can remove).
- **Show Auras Buff / Show Auras Debuff:** turn either one off to hide auras that have no duration (passives, paladin auras, toggles and other permanent effects), so only timed auras show.
- **Dispel-type borders on debuffs.** Magic, Curse, Disease and Poison each have their own color.
- **Works in combat.** The game client tracks and draws the auras itself, so they keep updating in combat at practically no performance cost.
- **Click-through icons.** Mouseover and click-casting on the pet frame keep working.
- **Saved in your EllesmereUI profile.** The settings live in the Raid Frames profile, so they follow profile switches.

## Requirements

- World of Warcraft client with the AuraContainer aura system: **WoW Forever** (Interface 16001) or 12.x.
- **EllesmereUI** and its **Raid Frames** module (`EllesmereUIRaidFrames`), with **Show Pets** enabled on the matching tab.
- Tested with EllesmereUI **9.5.4**.

## Installation

1. Download this repository (**Code → Download ZIP**) or a release.
2. Copy the add-on folder(s) into `World of Warcraft\_<client>_\Interface\AddOns\`:
   ```
   Interface/AddOns/
   ├── EllesmereUI_PetAuras_Partyframe/
   └── EllesmereUI_PetAuras_Raidframe/
   ```
   Keep the folder names exactly as they are, or the game will not load the add-ons.
3. Restart the game or type `/reload`.
4. Open EllesmereUI → **Raid Frames**, turn on **Show Pets** on the Party and/or Raid tab, and find the **PET AURAS** section below *PET FRAMES*.

## Settings

The PET AURAS section only appears while **Show Pets** is on for that tab.

| Row | Left | Right |
|---|---|---|
| 1 | Show Pet Buffs | Show Pet Debuffs |
| 2 | Show Auras Buff (permanent buffs on/off) | Show Auras Debuff (permanent debuffs on/off) |
| 3 | Aura Positions – **Move Auras** button | |
| Buffs, then Debuffs | Position (cog: X, Y, spacing) | Icon Size (cog: max icons, per row, border, stack size, filter) |
| | Timer (cog: timer position, X, Y) | Timer Size |
| | Timer Font | Timer Outline |

### Defaults

| | Party – Buffs | Party – Debuffs | Raid – Buffs | Raid – Debuffs |
|---|---|---|---|---|
| Position | Inside bottom left | Inside bottom right | Inside bottom left | Inside bottom right |
| Icon size | 16 | 18 | 12 | 14 |
| Max icons | 4 | 3 | 3 | 2 |
| Timer size | 9 | 9 | 8 | 8 |

## Slash commands

| Command | Action |
|---|---|
| `/papf` | Party: toggle move mode |
| `/papf reset` | Party: restore default settings |
| `/parf` | Raid: toggle move mode |
| `/parf reset` | Raid: restore default settings |

## How it works

- Each pet button gets its own aura containers (one per block), built on the client's `AuraContainer` / `CustomAuraContainerTemplate` system. The add-on never reads aura data. The client tracks and draws the auras, including secret auras in combat.
- The containers follow the pet button's unit, so they stay correct when the secure header re-sorts or reassigns pets, even in combat.
- *Show Auras Buff/Debuff* switches between two aura groups declared up front. One of them has a native "has duration" candidate filter, the same one the EllesmereUI Debuff Manager uses.
- Layout and style changes are applied out of combat only. Changes you make in combat apply when combat ends.
- The options are added by wrapping the Raid Frames options builder at runtime. No EllesmereUI file is touched.

## Known limitations

- Position and size changes made during combat apply when combat ends. Move mode turns off when you enter combat or close the settings window.
- After a size or font change, aura icons that already exist may keep their old look until `/reload`. The client limits changes to aura buttons after it creates them.
- The add-ons depend on internal EllesmereUI Raid Frames functions. A future EllesmereUI update may need a matching update here. If the PET AURAS section disappears from the options, that is the likely cause.

## Changelog

**1.0.1**
- *Only Dispellable* now shows the debuffs you can actually dispel (`RAID_PLAYER_DISPELLABLE`). Before, it showed raid-relevant debuffs instead.
- After a roster change, the visible pet frames re-read their auras, so a pet token handed to another pet never shows stale auras.
- Move mode turns off when the EllesmereUI settings window closes.
- Party add-on: a full re-apply now runs only when the party/raid layout actually changes.

**1.0.0**
- First release: party and raid pet auras, move mode with placeholders, a permanent-aura switch per block.
