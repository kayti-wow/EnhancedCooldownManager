# Enhanced Cooldown Manager (ECM)

## Purpose
A World of Warcraft addon that displays customizable resource bars anchored to Blizzard's Cooldown Manager viewer UI frames. Provides visual feedback for:
- Primary power resources (mana, rage, energy, runic power, etc.)
- Segmented resources (DK runes, DH souls, Paladin Holy Power, Warrior Whirlwind stacks)
- Buff/aura bars (restyling Blizzard's BuffBarCooldownViewer)

## Tech Stack
- **Language**: Lua 5.1 (WoW standard)
- **Framework**: Ace3
  - AceAddon-3.0 (addon lifecycle)
  - AceEvent-3.0 (event handling)
  - AceConsole-3.0 (slash commands)
  - AceDB-3.0 (saved variables)
  - AceConfig-3.0, AceGUI-3.0, AceDBOptions-3.0 (options UI)
- **Libraries**: LibSharedMedia-3.0 (textures/fonts)
- **Build**: None required - live reload via `/reload`

## WoW Interface Version
- 12.0.0, 12.0.1, 11.0.207 (Retail)

## Slash Commands
- `/ecm on|off|toggle|debug` - Control addon state
