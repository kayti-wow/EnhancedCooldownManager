# Enhanced Cooldown Manager by Solär

Enhanced Cooldown Manager creates a clean combat HUD around Blizzard's built-in cooldown manager that **looks and works great out of the box** and is **straightforward to customise.**

Made with ❤️, with little features you didn't know you needed and won't be able to live without.

##  Features

### ⚔️ Inline Resources

Adds essential combat bars directly below Blizzard's cooldown manager.

- `Power Bar` for mana, rage, energy, focus, and runic power
- `Resource Bar` for class resources
- `Rune Bar` for Death Knight rune tracking
- `Aura Bars` with unified style and color control

![Combat HUD screenshot placeholder](docs/images/feature-combat-hud.png)

### 🎨 Aura Bars

Make the built-in aura bars snap into position perfectly and match the styling of the HUD. The colour of each bar can be customised independently per spec so you can see the duration of specific auras at a glance.

![Buff Bars screenshot placeholder](docs/images/feature-buff-bars.png)

### 🙈 Smart Visibility and Fade Rules

Reduce screen clutter automatically based on gameplay context:

- Hide while mounted or in a vehicle
- Hide in rest areas
- Fade when out of combat
- Optionally stay visible in instances (raids, M+, PVP)
- Optionally stay visible when you have an attackable target

![Visibility rules screenshot placeholder](docs/images/feature-visibility-fade.png)

### 🟥 Death Knight Runes

Track each rune independently as it recharges inline with other resources and cooldowns.

![Rune Bar screenshot placeholder](docs/images/feature-rune-bar.png)

### 🧪 Add Icons for Trinkets, Potions, and Healthstones

Extend the utility cooldown bar with essential combat icons to save you a glance at the action bar.

- Equipped trinket cooldowns
- Health potion cooldown
- Combat potion cooldown
- Healthstone cooldown

![Item icons screenshot placeholder](docs/images/feature-item-icons.png)

### 📌 Automatic positioning or free movement

Use the layout mode that fits your setup.

- Auto-position directly under Blizzard's Cooldown Manager
- Detach modules and move them independently
- Mix and match layouts depending on preference

![Layout mode screenshot placeholder](docs/images/feature-layout-modes.png)

## Installation

1. Download and extract this addon into `World of Warcraft/_retail_/Interface/AddOns`.
2. Reload your UI or restart the game.

## Configuration

- Use `/ecm` in game to open options.
- You can also open it from the AddOn compartment menu near the minimap.

## Troubleshooting

If you run in a problem, enable debug tracing with the command `/ecm debug` and reload your UI. When the issue occurs again, type `/ecm bug`, copy the trace log and please include it when you open an issue.

## License

[GPL-3.0](LICENSE)
