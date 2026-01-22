# Codebase Structure

## Files
- `EnhancedCooldownManager.lua` - Addon bootstrap, defaults, slash commands
- `Utilities.lua` - Shared helpers (`ns.Util.*`)
- `Options.lua` - AceConfig options panel
- `Modules/PowerBar.lua` - Primary resource bar (mana/rage/energy)
- `Modules/SegmentBar.lua` - Segmented resources (runes, combo points, Holy Power)
- `Modules/BuffBars.lua` - Styles Blizzard's BuffBarCooldownViewer
- `Modules/ViewerHook.lua` - Mount/spec change handler

## Mixins (`ns.Mixins.*`)
- `Modules/Mixins/BarFrame.lua` - Frame creation, appearance, text overlay
  - `BarFrame.Create(frameName, parent, height)` - Creates bar with Background + StatusBar
  - `BarFrame.AddTextOverlay(bar, profile)` - Adds TextFrame + TextValue FontString
  - `BarFrame.AddTicksFrame(bar)` - Adds TicksFrame for segment dividers
  - `BarFrame.ApplyAppearance(bar, cfg, profile)` - Sets background color + texture
  - `BarFrame.SetValue(bar, min, max, current, r, g, b)` - Updates StatusBar
  - `BarFrame.SetText(bar, text)` / `SetTextVisible(bar, shown)` - Text helpers

- `Modules/Mixins/ModuleLifecycle.lua` - Enable/Disable, throttling, event helpers
  - `Lifecycle.Enable(module, moduleName, events)` - Sets _enabled, registers events
  - `Lifecycle.Disable(module, moduleName, events)` - Hides frame, unregisters events
  - `Lifecycle.OnEnable(module, moduleName, layoutEvents)` - Registers layout events
  - `Lifecycle.OnDisable(module, moduleName, layoutEvents, refreshEvents)` - Cleanup
  - `Lifecycle.CheckLayoutPreconditions(module, configKey, shouldShowFn, moduleName)` - Guards
  - `Lifecycle.ThrottledRefresh(module, profile, refreshFn)` - Throttled updates

- `Modules/Mixins/TickRenderer.lua` - Tick pooling and positioning
  - `TickRenderer.EnsureTicks(bar, count, parentFrame, poolKey)` - Pool management
  - `TickRenderer.HideAllTicks(bar, poolKey)` - Hides all ticks
  - `TickRenderer.LayoutSegmentTicks(bar, maxSegments, color, width, poolKey)` - Even spacing
  - `TickRenderer.LayoutValueTicks(bar, statusBar, ticks, max, defaultColor, defaultWidth, poolKey)` - Value positions

## Bar Anchor Chain
```
EssentialCooldownViewer → PowerBar → SegmentBar → BuffBarCooldownViewer
```
Use `Util.GetPreferredAnchor(addon, excludeModule)` for bottom-most visible bar.

## Module Interface
`:GetFrame()`, `:GetFrameIfShown()`, `:SetExternallyHidden(bool)`, `:UpdateLayout()`, `:Refresh()`, `:Enable()/:Disable()`

## Config
All in `EnhancedCooldownManager.db.profile` with module-specific subsections.
