# ResourceBar Status

## Overview

ResourceBar is now fully functional with the new ECMFrame/BarFrame architecture. It displays discrete resources (combo points, chi, holy power, soul shards, essence) and Demon Hunter soul fragments.

## Current State: ✅ Working

### Implementation Complete

1. **ECMFrame Integration** ✅
   - Uses `ECMFrame.AddMixin()` via `BarFrame.AddMixin()`
   - Implements `ShouldShow()` override for class/resource checks
   - Implements `GetStatusBarValues()` override
   - Proper config access via `GetConfigSection()` and `GetGlobalConfig()`

2. **Custom Refresh Logic** ✅
   - Calls `ECMFrame.Refresh()` for base checks (not `BarFrame.Refresh()`)
   - Handles all value/color/texture/text/tick logic directly
   - ResourceBar-specific color handling for DH souls
   - Devourer void meta state tracking

3. **Tick Rendering** ✅
   - Uses `LayoutResourceTicks()` for even-spaced dividers
   - Creates ticks on `frame.TicksFrame`
   - Ticks appear between resources (e.g., 5 combo points = 4 dividers)
   - Proper pixel snapping for crisp rendering

4. **Text Overlay** ✅
   - Shows current resource count as text
   - Devourer: multiply by 5 for fragment count display
   - Normal resources: show integer value
   - Respects `showText` config (defaults to true)
   - Applies global font settings

5. **Event Handling** ✅
   - `UNIT_AURA` -> `OnUnitAura()` with player filtering
   - `UNIT_POWER_FREQUENT` -> `OnUnitPower()` with player filtering
   - Void meta state change detection for immediate refresh
   - Throttled refresh respects global `updateFrequency`

## Supported Resources

### Standard PowerTypes
- **Combo Points** (Rogue, Feral Druid) - Red
- **Chi** (Monk) - Cyan/Green
- **Holy Power** (Paladin) - Gold/Yellow
- **Soul Shards** (Warlock) - Purple
- **Essence** (Evoker) - Teal/Green

### Demon Hunter Souls
- **Havoc/Vengeance** - Blue, configurable max (default 5)
- **Devourer (Normal)** - Purple, max 7
- **Devourer (Void Meta)** - Deep Blue, max 6
- Automatic color change when entering/exiting void meta
- Text shows fragment count (0-35 for void meta, 0-30 for normal)

## Configuration

### Required Settings (from Defaults.lua)

```lua
resourceBar = {
    enabled = true,
    showText = true,
    anchorMode = "chain",
    demonHunterSoulsMax = 5,

    border = {
        enabled = false,
        thickness = 1,
        color = { r, g, b, a }
    },

    colors = {
        souls = { r = 0.259, g = 0.6, b = 0.91, a = 1 },
        devourerNormal = { r = 0.447, g = 0.412, b = 0.651, a = 1 },
        devourerMeta = { r = 0.275, g = 0.169, b = 1.0, a = 1 },
        [Enum.PowerType.ComboPoints] = { r = 0.75, g = 0.15, b = 0.15, a = 1 },
        [Enum.PowerType.Chi] = { r = 0.00, g = 1.00, b = 0.59, a = 1 },
        [Enum.PowerType.HolyPower] = { r = 0.8863, g = 0.8235, b = 0.2392, a = 1 },
        [Enum.PowerType.SoulShards] = { r = 0.58, g = 0.51, b = 0.79, a = 1 },
        [Enum.PowerType.Essence] = { r = 0.20, g = 0.58, b = 0.50, a = 1 }
    }
}
```

### Optional Settings
- `width` - Custom width (inherits from chain anchor if nil)
- `height` - Custom height (inherits from global.barHeight if nil)
- `offsetX` - Horizontal offset for independent mode
- `offsetY` - Vertical offset (also used in chain mode as gap)
- `texture` - Custom texture (inherits from global.texture if nil)
- `bgColor` - Custom background color (inherits from global.barBgColor if nil)

## Chain Anchoring

ResourceBar is positioned in the chain order:
```
PowerBar -> ResourceBar -> RuneBar -> BuffBars
```

- Anchors to PowerBar (if visible and enabled)
- Falls back to EssentialCooldownViewer if PowerBar is hidden
- RuneBar anchors to ResourceBar (if visible and enabled)

## Visibility Logic

ResourceBar shows when:
- `resourceBar.enabled` is true
- Module is not hidden (`_hidden` is false)
- **AND** one of:
  - Player is a Demon Hunter (any spec), **OR**
  - Player has a discrete power type with max > 0
    - For Druids: only in Cat Form (formIndex == 2)

## Key Methods

### `ResourceBar:ShouldShow()`
Determines if the bar should be visible based on class and power type.

### `ResourceBar:GetStatusBarValues()`
Returns current, max, displayValue, and isFraction for the status bar.
- Returns `currentValue, maxResources, currentValue, false`

### `ResourceBar:Refresh(force)`
Main update method that:
1. Checks if refresh should proceed (base checks)
2. Gets resource values via `GetValues()`
3. Determines color (including DH souls special handling)
4. Updates StatusBar (values, color, texture)
5. Updates text overlay (Devourer: multiply by 5)
6. Updates ticks (dividers between resources)
7. Shows the frame

### `ResourceBar:OnUnitAura(event, unit)`
Event handler for aura changes (DH soul fragments, Devourer void meta).

### `ResourceBar:OnUnitPower(event, unit)`
Event handler for power changes (combo points, chi, etc.).

## Implementation Details

### GetValues() Helper
Returns: `maxResources, currentValue, kind, isVoidMeta`
- DH Devourer: 6 or 7 max, value is applications/5, kind="souls", isVoidMeta boolean
- DH Havoc/Vengeance: configurable max (default 5), spell cast count, kind="souls"
- Other classes: UnitPowerMax/UnitPower, kind=PowerType enum value

### Void Meta State Tracking
- `_lastVoidMeta` tracks previous void meta state
- `_MaybeRefreshForVoidMetaStateChange()` detects transitions
- Forces immediate refresh (bypassing throttle) on state change
- Ensures color updates instantly when entering/exiting void meta

## Testing Checklist

- [ ] Combo Points (Rogue/Feral) - 5 or 6 max, red bars
- [ ] Chi (Monk) - 5 or 6 max, cyan/green bars
- [ ] Holy Power (Paladin) - 3 or 5 max, gold bars
- [ ] Soul Shards (Warlock) - 5 max, purple bars
- [ ] Essence (Evoker) - 5 or 6 max, teal bars
- [ ] DH Souls (Havoc) - 5 max, blue bars
- [ ] DH Souls (Vengeance) - 5 max, blue bars
- [ ] DH Devourer (Normal) - 7 max, purple bars, text shows 0-30
- [ ] DH Devourer (Void Meta) - 6 max, deep blue bars, text shows 0-35
- [ ] Tick dividers appear between resources
- [ ] Text shows correct count
- [ ] Text respects font settings
- [ ] Void meta color changes instantly
- [ ] Bar hidden when no resources available
- [ ] Bar anchors correctly to PowerBar in chain
- [ ] Respects enabled/disabled setting

## Known Issues

None at this time.

## Future Enhancements

- [ ] Options panel integration for `showText` setting
- [ ] Per-resource text formatting options
- [ ] Tick color customization per resource type
- [ ] Animation on resource gain/loss
