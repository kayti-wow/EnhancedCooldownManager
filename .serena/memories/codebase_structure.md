# Codebase Structure

## Root Files
| File | Purpose |
|------|---------|
| `EnhancedCooldownManager.lua` | Ace3 addon bootstrap, defaults, config types, slash commands |
| `Utilities.lua` | Shared helpers: `ns.Util.*` (PixelSnap, GetBgColor, ApplyBarAppearance, etc.) |
| `Options.lua` | AceConfig options panel definition |
| `SparkleUtil.lua` | Sparkle animation utility |
| `EnhancedCooldownManager.toc` | WoW addon manifest |

## Modules Directory
| File | Purpose |
|------|---------|
| `Modules/PowerBar.lua` | AceModule for primary resource bar (mana/rage/energy/runic power) |
| `Modules/SegmentBar.lua` | AceModule for fragmented resources (DK runes, Holy Power, etc.) |
| `Modules/BuffBars.lua` | AceModule that styles Blizzard's BuffBarCooldownViewer children |
| `Modules/ProcOverlay.lua` | AceModule for proc overlays |
| `Modules/ViewerHook.lua` | Central event handler for mount/spec changes; triggers layout updates |

## Bar Anchor Chain
Bars stack vertically below EssentialCooldownViewer:
```
EssentialCooldownViewer (Blizzard icons)
    ↓ PowerBar (if visible)
    ↓ SegmentBar (if visible)
    ↓ BuffBarCooldownViewer (Blizzard, restyled by BuffBars)
```

## Common Module Interface
All bar modules expose:
- `:GetFrame()` - Lazy-creates and returns the module's frame
- `:GetFrameIfShown()` - Returns frame only if currently visible
- `:SetExternallyHidden(bool)` - Hides frame externally (e.g., mounted)
- `:UpdateLayout()` - Positions/sizes/styles the frame
- `:Refresh()` - Updates values only (colors, text, progress)
- `:Enable()` / `:Disable()` - Registers/unregisters events

## Configuration Storage
- All settings in `EnhancedCooldownManager.db.profile`
- Module-specific: `profile.powerBar`, `profile.segmentBar`, `profile.dynamicBars`
- Global defaults: `profile.global.{barHeight, texture, font, fontSize, barBgColor}`
- Colors: `profile.powerTypeColors.colors[PowerType]`
