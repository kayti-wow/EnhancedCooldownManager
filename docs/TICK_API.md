# Tick Rendering API

## Overview

The BarFrame mixin provides tick rendering capabilities for displaying markers on status bars. Ticks are small vertical lines that indicate resource divisions (e.g., combo point separators) or specific value thresholds (e.g., energy breakpoints).

## Core Methods

### `BarFrame:EnsureTicks(count, parentFrame, poolKey)`

Ensures the tick pool has the required number of ticks. Creates new ticks as needed, shows required ticks, hides extras.

**Parameters:**
- `count` (number) - Number of ticks needed
- `parentFrame` (Frame) - Frame to create ticks on (typically `frame.TicksFrame`)
- `poolKey` (string|nil) - Key for tick pool on module (default "tickPool")

**Usage:**
```lua
self:EnsureTicks(tickCount, frame.TicksFrame, "tickPool")
```

### `BarFrame:HideAllTicks(poolKey)`

Hides all ticks in the specified pool.

**Parameters:**
- `poolKey` (string|nil) - Key for tick pool (default "tickPool")

**Usage:**
```lua
self:HideAllTicks("tickPool")
```

### `BarFrame:LayoutResourceTicks(maxResources, color, tickWidth, poolKey)`

Positions ticks evenly as resource dividers. Used by ResourceBar to show divisions between resources (e.g., 5 combo points = 4 tick dividers).

**Parameters:**
- `maxResources` (number) - Number of resources (ticks = maxResources - 1)
- `color` (ECM_Color|nil) - RGBA color table (default black: `{ r = 0, g = 0, b = 0, a = 1 }`)
- `tickWidth` (number|nil) - Width of each tick in pixels (default 1)
- `poolKey` (string|nil) - Key for tick pool (default "tickPool")

**Usage:**
```lua
local tickCount = math.max(0, maxResources - 1)
self:EnsureTicks(tickCount, frame.TicksFrame, "tickPool")
self:LayoutResourceTicks(maxResources, { r = 0, g = 0, b = 0, a = 1 }, 1, "tickPool")
```

**Behavior:**
- Divides bar width evenly by `maxResources`
- Positions ticks at resource boundaries
- Anchors ticks to the inner frame (left edge)
- Uses pixel snapping for crisp rendering

### `BarFrame:LayoutValueTicks(statusBar, ticks, maxValue, defaultColor, defaultWidth, poolKey)`

Positions ticks at specific resource values. Used by PowerBar for breakpoint markers (e.g., energy thresholds for abilities).

**Parameters:**
- `statusBar` (StatusBar) - StatusBar to position ticks on (typically `frame.StatusBar`)
- `ticks` (table) - Array of tick definitions: `{ { value = number, color = ECM_Color, width = number }, ... }`
- `maxValue` (number) - Maximum resource value
- `defaultColor` (ECM_Color) - Default RGBA color for ticks without custom color
- `defaultWidth` (number) - Default tick width for ticks without custom width
- `poolKey` (string|nil) - Key for tick pool (default "tickPool")

**Tick Definition:**
```lua
{
    value = 35,  -- Power value where tick appears
    color = { r = 1, g = 1, b = 0, a = 0.8 },  -- Optional custom color
    width = 2  -- Optional custom width
}
```

**Usage:**
```lua
local ticks = self:GetCurrentTicks()  -- Get class/spec-specific ticks
self:EnsureTicks(#ticks, frame.TicksFrame, "tickPool")
self:LayoutValueTicks(frame.StatusBar, ticks, maxPower, defaultColor, defaultWidth, "tickPool")
```

**Behavior:**
- Positions each tick at `(value / maxValue) * barWidth`
- Anchors ticks to the StatusBar (left edge)
- Hides ticks with invalid values (≤ 0 or ≥ maxValue)
- Uses pixel snapping for crisp rendering

## Implementation Details

### Tick Storage

Ticks are stored in pools on the **module** (not the frame):
```lua
self.tickPool = { tick1, tick2, tick3, ... }
```

This allows tick textures to persist across frame refreshes.

### Tick Creation

Ticks are created as **Texture** objects on a parent frame:
```lua
local tick = parentFrame:CreateTexture(nil, "OVERLAY")
```

Conventionally, ticks should be created on `frame.TicksFrame` for proper z-ordering and organization.

### Frame Access

All tick layout methods use `self:GetInnerFrame()` to access frame properties:
```lua
local frame = self:GetInnerFrame()
local barWidth = frame:GetWidth()
local barHeight = frame:GetHeight()
```

This ensures methods work correctly when called on modules (where `self` is the module, not the frame).

## Examples

### ResourceBar (Even Spacing)

```lua
function ResourceBar:Refresh(force)
    -- ... value calculations ...

    local tickCount = math.max(0, maxResources - 1)
    self:EnsureTicks(tickCount, frame.TicksFrame, "tickPool")
    self:LayoutResourceTicks(maxResources, { r = 0, g = 0, b = 0, a = 1 }, 1, "tickPool")
end
```

### PowerBar (Value-Based)

```lua
function PowerBar:UpdateTicks(frame, resource, max)
    local ticks = self:GetCurrentTicks()  -- Class/spec-specific config
    if not ticks or #ticks == 0 then
        self:HideAllTicks("tickPool")
        return
    end

    local defaultColor = { r = 1, g = 1, b = 1, a = 0.8 }
    local defaultWidth = 1

    self:EnsureTicks(#ticks, frame.TicksFrame, "tickPool")
    self:LayoutValueTicks(frame.StatusBar, ticks, max, defaultColor, defaultWidth, "tickPool")
end
```

## Configuration

### Global Tick Settings (Not Yet Implemented)

Future: Global tick settings may be added to `profile.global`:
```lua
{
    tickColor = { r = 1, g = 1, b = 1, a = 0.8 },
    tickWidth = 1,
    tickEnabled = true
}
```

### Module-Specific Tick Config

PowerBar supports per-class/spec tick configuration:
```lua
profile.powerBar.ticks = {
    enabled = true,
    defaultColor = { r = 1, g = 1, b = 1, a = 0.8 },
    defaultWidth = 1,
    mappings = {
        [classID] = {
            [specID] = {
                { value = 35, color = {...}, width = 2 },
                { value = 50 },
                ...
            }
        }
    }
}
```

## Status

✅ **Working:** Tick rendering API is functional
✅ **Working:** ResourceBar uses even-spaced ticks
✅ **Working:** PowerBar supports value-based ticks
⏳ **Not Connected:** Options panel integration pending
⏳ **Future:** Global tick settings (color, width, enabled)

## Migration Notes

### Changes from Previous Implementation

1. **Frame Access:** Methods now use `self:GetInnerFrame()` instead of assuming `self` is the frame
2. **Tick Parent:** Ticks created on `frame.TicksFrame` instead of `frame.StatusBar`
3. **Anchoring:** `LayoutResourceTicks` anchors to frame, `LayoutValueTicks` anchors to statusBar
4. **Pool Location:** Tick pools stored on module, not frame

### Breaking Changes

None - the API is new/restored, not changed from a working implementation.
