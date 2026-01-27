# Codebase Structure

## Files
- `EnhancedCooldownManager.lua` - Addon bootstrap, defaults, slash commands
- `Utilities.lua` - Debug logging (`Util.Log`), pixel snapping (`Util.PixelSnap`)
- `Options.lua` - AceConfig options panel
- `Modules/PowerBar.lua` - Primary resource bar (mana/rage/energy)
- `Modules/ResourceBar.lua` - Resourceed resources (combo points, Holy Power, Chi)
- `Modules/RuneBar.lua` - Death Knight runes with recharge animation
- `Modules/BuffBars.lua` - Styles Blizzard's BuffBarCooldownViewer
- `Modules/ViewerHook.lua` - Mount/spec change handler

## Mixins (`ns.Mixins.*`)

### BarFrame (`Modules/Mixins/BarFrame.lua`)
Frame creation, layout, appearance, text overlay. Uses object-based pattern (methods attached to bars).

**Constants:** `DEFAULT_POWER_BAR_HEIGHT`, `DEFAULT_RESOURCE_BAR_HEIGHT`, `DEFAULT_BG_COLOR`

**Helpers (module-level):**
- `BarFrame.GetBarHeight(cfg, profile, fallback)` - Resolved bar height
- `BarFrame.GetTopGapOffset(cfg, profile)` - Top gap for first bar
- `BarFrame.GetBgColor(cfg, profile)` - Background color
- `BarFrame.GetTexture(textureOverride)` - LSM-resolved texture
- `BarFrame.ApplyFont(fontString, profile)` - Apply font settings
- `BarFrame.GetViewerAnchor()` - EssentialCooldownViewer or UIParent
- `BarFrame.CalculateAnchor(addon, moduleName)` - Anchor for a bar module (nil = bottom-most, or previous bar in chain)

**Bar methods (attached during Create):**
- `bar:SetLayout(anchor, offsetX, offsetY, height, width, isIndependent)` - Apply layout (cached)
- `bar:SetAppearance(cfg, profile)` - Apply appearance (bg color, texture)
- `bar:SetValue(min, max, current, r, g, b)` - Update StatusBar value and color
- `bar:ApplyConfig(module)` - Complete layout/appearance from profile

**Text methods (attached via AddTextOverlay):**
- `bar:SetText(text)`
- `bar:SetTextVisible(shown)`

### ModuleLifecycle (`Modules/Mixins/ModuleLifecycle.lua`)
Enable/Disable, event registration, throttled refresh. Injects methods onto modules.

**Lifecycle.Setup(module, config)** injects:
- `module:OnEnable()` - Registers events, calls UpdateLayout
- `module:OnDisable()` - Unregisters events, hides frame
- `module:SetExternallyHidden(hidden)` - External visibility control
- `module:GetFrameIfShown()` - Frame if visible

**Auto-generated UpdateLayout** (when `configKey` provided):
- Checks preconditions, calculates anchor, applies layout
- Calls `onLayoutSetup` hook for module-specific setup
- Config options: `configKey`, `shouldShow`, `defaultHeight`
- `anchorMode`: `"chain"` (auto-position in stack) or `"independent"` (custom position)

**Static helpers:**
- `Lifecycle.CheckLayoutPreconditions(module, configKey, shouldShowFn, moduleName)`
- `Lifecycle.ThrottledRefresh(module, profile, refreshFn)`

### TickRenderer (`Modules/Mixins/TickRenderer.lua`)
Tick pooling and positioning. Uses `TickRenderer.AttachTo(bar)` to attach methods.

**Bar methods (attached via AttachTo):**
- `bar:EnsureTicks(count, parentFrame, poolKey)`
- `bar:HideAllTicks(poolKey)`
- `bar:LayoutResourceTicks(maxResources, color, width, poolKey)`
- `bar:LayoutValueTicks(statusBar, ticks, max, defaultColor, defaultWidth, poolKey)`

## Bar Anchor Chain
```
EssentialCooldownViewer → PowerBar → ResourceBar → RuneBar → BuffBarCooldownViewer
```
Use `BarFrame.CalculateAnchor(addon, moduleName)` to find the anchor:
- `moduleName = nil` → bottom-most visible bar (for BuffBars)
- `moduleName = "RuneBar"` → previous visible bar in chain (for bar modules)

## Module Interface
`:GetFrame()`, `:GetFrameIfShown()`, `:SetExternallyHidden(bool)`, `:UpdateLayout()`, `:Refresh()`, `:Enable()/:Disable()`

## Config
All in `EnhancedCooldownManager.db.profile` with module-specific subsections.
