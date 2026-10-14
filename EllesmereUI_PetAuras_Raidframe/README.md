# EllesmereUI Pet Auras (Raid Frames)

Shows buffs and debuffs on the **EllesmereUI Raid Frames raid pet frames**, the pets shown alongside the raid frames (up to 40). Buffs and debuffs are separate blocks, and you position and style each one on its own.

A standalone plugin for EllesmereUI. It does not modify any EllesmereUI file. For the party pet frames, use the companion add-on **EllesmereUI Pet Auras (Party Frames)**. The two have separate settings and can run side by side.

## Features

- **Separate buff and debuff blocks.** Turn each on or off, and place each one above, below, left of or right of the pet frame, or inside any of its corners. Fine-tune with X/Y offsets.
- **Move mode with placeholders.** Click **Move Auras**, or type `/parf`, to show 3 placeholder auras per block on the raid pet frames and on the options preview. Drag a colored block to move it. Right-click a block to reset its offset.
- **Icon settings:** size, spacing, max icons, icons per row, border and stack text size.
- **Timer settings:** on/off, size, position (top / center / bottom plus X/Y), font (any EllesmereUI or SharedMedia font; the default is the Raid Frames font) and outline.
- **Filters:** *Only Mine* for buffs, *Only Dispellable* for debuffs.
- **Show Auras Buff / Show Auras Debuff:** a separate switch for buffs and for debuffs. Turn it off to hide auras that have no duration (passives, paladin auras, toggles and other permanent effects), so only timed auras show. The client does this filtering itself, in combat too.
- **Dispel-type borders on debuffs.** Magic, Curse, Disease and Poison each have their own color.
- **Works in combat.** The game client tracks and draws the auras itself (the AuraContainer system), so they keep updating in combat with practically no performance cost.
- **Click-through icons.** Mouseover and click-casting on the pet frame keep working.
- **Saved in your EllesmereUI profile.** The settings live in the Raid Frames profile, so they follow profile switches.

## Where it works

- Raid pets in the **pet header** (Before First Group / After Last Group / Free Move) while the raid frames are on screen.
- When the party frames are on screen (party, and small raids or arenas shown with the party frames), these blocks stay hidden. The Party Frames add-on covers those pets.

## Settings

**Raid Frames > Raid tab > PET AURAS.** The section sits below *PET FRAMES* and only appears while **Show Pets** is enabled on the Raid tab.

## Slash commands

| Command | Action |
|---|---|
| `/parf` | Toggle move mode |
| `/parf reset` | Restore default settings |

## Requirements

- EllesmereUI and EllesmereUI Raid Frames
- A client with the AuraContainer system (WoW Forever / 12.x)

## Notes

- The defaults are smaller than the party version (buffs 12 px, max 3; debuffs 14 px, max 2), because raid pet frames are small.
- Position and size changes made during combat apply when combat ends. Move mode turns off when you enter combat.
- After a size or font change, aura icons that already exist may keep their old look until a `/reload`. The client limits changes to icons after it creates them.
