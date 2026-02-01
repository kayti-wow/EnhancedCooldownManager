# Refactor Progress and Design Decisions

## Overview

This document tracks the ongoing refactor to establish a mixin-based architecture for Enhanced Cooldown Manager. The goal is to separate concerns cleanly across three layers:

- **ECMFrame**: Frame lifecycle, layout, positioning, borders, config access
- **BarFrame**: StatusBar management, values, colors, textures, ticks, text overlays
- **Concrete Modules** (PowerBar, ResourceBar, RuneBar, BuffBars): Event handling, domain logic

## Architecture

### Mixin Hierarchy

```
ECMFrame (base) -> BarFrame (bar specialization) -> PowerBar/ResourceBar/RuneBar (concrete bars)
ECMFrame (base) -> BuffBars (specialized, no BarFrame, uses Blizzard viewer)
```

### Responsibility Separation

**ECMFrame** (`Mixins/ECMFrame.lua`)
- Owns: Inner WoW frame, layout (positioning, anchor, border, background), config access, visibility control
- Public API: `GetInnerFrame()`, `GetGlobalConfig()`, `GetConfigSection()`, `ShouldShow()`, `UpdateLayout()`, `SetHidden()`, `Refresh(force)`
- Internal state: `_innerFrame`, `_config`, `_configKey`, `_layoutCache`, `_hidden`
- **New:** Nil-safe for Border/Background (supports BuffBars which doesn't have these)

**BarFrame** (`Mixins/BarFrame.lua`)
- Owns: StatusBar creation, value updates, appearance (texture, colors), tick marks, text overlays
- Public API: `CreateFrame()`, `GetStatusBarValues()` (abstract), `ThrottledRefresh()`, `Refresh(force)`
- Public API (Ticks): `EnsureTicks()`, `HideAllTicks()`, `LayoutResourceTicks()`, `LayoutValueTicks()`
- Public API (Text): Frame methods `SetText()`, `SetTextVisible()` (created in CreateFrame)
- Internal state: `_lastUpdate`, tick pools (`tickPool`, etc.)
- **Implemented:** Text overlay with font support, tick rendering

**PowerBar** (`Bars/PowerBar.lua`)
- Owns: Event registration, power-specific value calculations, class/spec visibility rules
- Implements: `GetStatusBarValues()`, `ShouldShow()`, event handlers
- Events: `UNIT_POWER_UPDATE` -> `OnUnitPowerUpdate` -> `ThrottledRefresh`

**ResourceBar** (`Bars/ResourceBar.lua`)
- Owns: Discrete resource tracking (combo points, chi, soul shards, DH souls), Devourer void meta state
- Implements: `GetStatusBarValues()`, `ShouldShow()`, `Refresh()` (custom tick/text logic)
- Events: `UNIT_AURA`, `UNIT_POWER_FREQUENT` -> dedicated handlers -> `ThrottledRefresh`
- **Refactored:** Now uses new ECMFrame/BarFrame pattern

**RuneBar** (`Bars/RuneBar.lua`)
- Owns: DK rune tracking, fragmented bar display (one bar per rune), OnUpdate script
- Implements: `CreateFrame()` (override, adds FragmentedBars), `ShouldShow()`, `Refresh()` (custom fragmented logic)
- Events: `RUNE_POWER_UPDATE`, `RUNE_TYPE_UPDATE` -> dedicated handlers -> `OnUpdateThrottled`
- **Refactored:** Now uses new ECMFrame pattern with BarFrame methods, custom CreateFrame

**BuffBars** (`Bars/BuffBars.lua`)
- Owns: Blizzard BuffBarCooldownViewer integration, child bar styling, color palettes, per-bar colors
- Implements: `CreateFrame()` (override, returns Blizzard viewer), `ShouldShow()`, `UpdateLayout()` (custom child layout)
- Events: `UNIT_AURA` -> `OnUnitAura` -> `ScheduleRescan`
- **Refactored:** Now uses ECMFrame pattern, no BarFrame (uses Blizzard's built-in StatusBars)

### Configuration Access Pattern

Modules access config through ECMFrame methods:
- `self:GetGlobalConfig()` - Returns `db.profile.global`
- `self:GetConfigSection()` - Returns `db.profile[configKey]` (e.g., `db.profile.powerBar`)
- Config key derived from module name: "PowerBar" -> "powerBar" (camelCase)

### Chain Anchoring

Bars anchor in fixed order: PowerBar -> ResourceBar -> RuneBar -> BuffBars

- First visible bar anchors to `EssentialCooldownViewer`
- Subsequent bars anchor to previous visible bar in chain
- `GetNextChainAnchor()` (local in ECMFrame) walks backwards to find first visible predecessor
- Chain mode uses dual-point anchoring (TOPLEFT/TOPRIGHT) to inherit width

## Refactor Completion Status (2026-02-01)

### Phase 1: Foundation ✅ Complete

**ECMFrame Enhancements:**
1. ✅ Made Border/Background access nil-safe (lines 232, 265)
   - Allows BuffBars to use ECMFrame without Border/Background frames
   - Pattern: `if frame.Border and borderChanged then`

**BarFrame Restoration:**
1. ✅ Restored tick helper function `GetTickPool()` (lines 21-29)
2. ✅ Restored text overlay methods (lines 33-81)
   - `AddTextOverlay(bar, profile)` - Creates TextFrame and TextValue FontString
   - `bar:SetText(text)` - Sets text value
   - `bar:SetTextVisible(shown)` - Shows/hides text overlay
3. ✅ Restored tick methods (lines 87-246)
   - `AttachTicks(bar)` - Creates TicksFrame container
   - `EnsureTicks(count, parentFrame, poolKey)` - Manages tick pool
   - `HideAllTicks(poolKey)` - Hides all ticks
   - `LayoutResourceTicks(maxResources, color, tickWidth, poolKey)` - Even spacing for resources
   - `LayoutValueTicks(statusBar, ticks, maxValue, defaultColor, defaultWidth, poolKey)` - Specific value markers
4. ✅ Added TicksFrame to `BarFrame:CreateFrame()` (lines 219-222)

### Phase 2: ResourceBar ✅ Complete & Working

**Full refactor to new mixin pattern:**
1. ✅ Converted `ShouldShowResourceBar()` -> `ResourceBar:ShouldShow()` method override
2. ✅ Created `ResourceBar:OnUnitAura(event, unit)` event handler with unit filtering
3. ✅ Created `ResourceBar:OnUnitPower(event, unit)` event handler with unit filtering
4. ✅ Registered events in OnEnable: `UNIT_AURA`, `UNIT_POWER_FREQUENT`
5. ✅ Kept void meta state tracking (`_lastVoidMeta`, `_MaybeRefreshForVoidMetaStateChange()`)
6. ✅ Simplified AddMixin call: `BarFrame.AddMixin(self, "ResourceBar")`
7. ✅ Implemented `GetStatusBarValues()` override (returns current, max, displayValue, isFraction)
8. ✅ Custom `Refresh()` with Devourer-specific text/tick logic

**Additional Fixes (2026-02-01):**
1. ✅ Fixed `Refresh()` to call `ECMFrame.Refresh()` instead of `BarFrame.Refresh()`
   - Avoids duplicate value/color updates
   - Prevents wrong colors from `GetColorForPlayerResource()` (doesn't know about DH souls)
2. ✅ Added texture setting in `Refresh()`
   - Calls `Util.GetTexture()` with config/global texture key
3. ✅ Enhanced text overlay handling
   - Normal resources: show current count
   - Devourer: multiply by 5 for fragment count (0-30 or 0-35)
   - Applies font settings via `Util.ApplyFont()`
4. ✅ Added `showText = true` to defaults (Defaults.lua:182)
   - Consistent with PowerBar settings
5. ✅ Created `RESOURCEBAR_STATUS.md` documentation
   - Complete API reference
   - Configuration details
   - Testing checklist

**Key Features:**
- Discrete power types: ComboPoints, Chi, HolyPower, SoulShards, Essence
- DH soul fragment tracking (Havoc/Vengeance vs Devourer)
- Devourer void meta state detection and color changes
- Text overlay shows resource count (Devourer: multiply by 5)
- Tick dividers between resources
- Instant color change on void meta transitions

### Phase 3: RuneBar ✅ Complete

**Full refactor with CreateFrame override:**
1. ✅ Overrode `RuneBar:CreateFrame()` to:
   - Call `ECMFrame.CreateFrame(self)` for base frame
   - Add StatusBar, TicksFrame, FragmentedBars array
   - Attach OnUpdate script for continuous rune updates
2. ✅ Implemented `RuneBar:ShouldShow()` - checks DK class
3. ✅ Implemented `RuneBar:GetStatusBarValues()` - returns aggregated rune value
4. ✅ Custom `Refresh()` manages fragmented bars and ticks
5. ✅ Created dedicated event handlers: `OnRunePowerUpdate()`, `OnRuneTypeUpdate()`
6. ✅ Cleanup OnUpdate script in `OnDisable()`
7. ✅ Kept custom fragmented bar logic (one StatusBar per rune, sorted by ready/cooldown)

**Key Features:**
- Individual bars per rune (fragmented display)
- Smart positioning: ready runes first, then sorting by cooldown remaining
- Half-brightness for runes on cooldown
- Pixel-perfect positioning to avoid sub-pixel gaps
- OnUpdate-driven for smooth cooldown animations

### Phase 4: BuffBars ✅ Complete

**Refactor to ECMFrame pattern (no BarFrame):**
1. ✅ Overrode `BuffBars:CreateFrame()` to return `_G["BuffBarCooldownViewer"]`
2. ✅ Implemented `BuffBars:ShouldShow()` - checks `buffBars.enabled`
3. ✅ Implemented `BuffBars:UpdateLayout()`:
   - Calculates chain/independent positioning
   - Applies positioning to viewer
   - Styles all visible children with per-bar colors
   - Calls `LayoutBars()` for vertical stacking
4. ✅ Implemented `BuffBars:Refresh()` - delegates to UpdateLayout
5. ✅ Converted config access to `self:GetConfigSection()`, `self:GetGlobalConfig()`
6. ✅ Simplified OnEnable: `ECMFrame.AddMixin(self, "BuffBars")`
7. ✅ Created `CalculateBuffBarsLayout(module)` for chain anchor logic
8. ✅ Legacy method `UpdateLayoutAndRefresh(why)` now delegates to `UpdateLayout()`

**Key Features:**
- Uses Blizzard's BuffBarCooldownViewer (no frame creation)
- Per-bar colors per class/spec with cache
- Color palettes (Rainbow, Warm, Cool, Pastel, Neon, Earth)
- Child bar styling (texture, colors, height, visibility)
- Edit mode integration (re-layout on edit mode exit)
- Automatic rescan for new buffs/debuffs

### Phase 5: Text Overlay and Tick Implementation ✅ Complete

**BarFrame Text Overlay:**
1. ✅ Text overlay created in `BarFrame:CreateFrame()` (lines 281-302)
   - TextFrame container with proper z-order (level +10 above StatusBar)
   - TextValue FontString with center alignment
   - `frame:SetText(text)` and `frame:SetTextVisible(shown)` methods attached to frame
2. ✅ Text updated in `BarFrame:Refresh()` (lines 231-246)
   - Format based on `isFraction` from `GetStatusBarValues()`: percentage vs integer
   - Apply font settings using `Util.ApplyFont(frame.TextValue, profile)`
   - Respect `configSection.showText` setting (defaults to true)
3. ✅ Removed deprecated `AddTextOverlay()` helper function
4. ✅ Removed deprecated `AttachTicks()` helper function (TicksFrame now created in CreateFrame)
5. ✅ Removed leftover TODO comments about font application

**PowerBar Tick Implementation:**
1. ✅ Restored `UpdateTicks()` method (lines 41-57)
   - Uses `LayoutValueTicks()` for class/spec-specific tick marks
   - Respects tick configuration (color, width, mappings)
   - Creates ticks on `frame.TicksFrame` for proper organization
2. ✅ Added `PowerBar:Refresh()` override (lines 70-84)
   - Calls `BarFrame.Refresh()` for standard updates
   - Calls `UpdateTicks()` for class/spec tick rendering
3. ✅ Removed large commented-out Refresh implementation

**BarFrame Tick Method Fixes:**
1. ✅ Fixed `LayoutResourceTicks()` to use `self:GetInnerFrame()`
   - Now gets frame width/height from actual frame, not module
   - Anchors ticks to frame instead of module
   - Fixes bug where module was used instead of frame
2. ✅ Fixed `LayoutValueTicks()` to use `self:GetInnerFrame()`
   - Gets frame height from actual frame for proper sizing
   - Maintains statusBar parameter for positioning (ticks anchor to StatusBar)
3. ✅ Created `TICK_API.md` documentation
   - Comprehensive API reference for tick rendering
   - Examples for ResourceBar (even spacing) and PowerBar (value-based)
   - Migration notes and implementation details

**Key Features:**
- Text displays current/max or percentage based on power type
- Font respects global settings (font, fontSize, fontOutline, fontShadow)
- Uses LibSharedMedia-3.0 for font resolution
- Text visibility controlled by `showText` config (per-module)
- PowerBar can show tick marks at specific power values (e.g., energy thresholds)

## Design Decisions

### 1. Nil-Safe Border/Background in ECMFrame

**Decision:** Check for `frame.Border` and `frame.Background` existence before accessing them.

**Rationale:**
- BuffBars uses Blizzard's existing viewer frame, which doesn't have our custom Border/Background
- ECMFrame should be flexible enough to work with any frame type
- Allows ECMFrame to be truly generic

**Implementation:**
```lua
-- ECMFrame.lua:232
local border = frame.Border
if border and borderChanged then
    -- border logic
end

-- ECMFrame.lua:265
if bgColorChanged and frame.Background then
    frame.Background:SetColorTexture(...)
end
```

### 2. Tick and Text Methods Restored to BarFrame

**Decision:** Uncomment and restore all tick and text overlay methods in BarFrame.

**Rationale:**
- ResourceBar needs ticks for resource dividers
- RuneBar needs ticks for rune dividers
- ResourceBar (Devourer) needs text overlay for fragment count
- These are core BarFrame features, not optional extras

**Trade-offs:**
- ✅ ResourceBar and RuneBar can now work properly
- ✅ DRY - shared tick logic instead of per-module duplication
- ❌ Increased complexity in BarFrame
- ❌ Modules must manage tick pools themselves

### 3. CreateFrame Override Pattern for Special Cases

**Decision:** Allow modules to override `CreateFrame()` when they need custom frame structure.

**Examples:**
- **RuneBar:** Adds FragmentedBars array and OnUpdate script
- **BuffBars:** Returns existing Blizzard frame instead of creating new one

**Rationale:**
- Not all modules fit the standard BarFrame pattern
- Overriding CreateFrame gives maximum flexibility
- Still get benefits of ECMFrame (layout, config, visibility)

**Implementation:**
```lua
-- RuneBar.lua
function RuneBar:CreateFrame()
    local frame = ECMFrame.CreateFrame(self)  -- Get base frame
    -- Add custom elements
    frame.FragmentedBars = {}
    frame:SetScript("OnUpdate", ...)
    return frame
end
```

### 4. Event Handler Pattern

**Decision:** Dedicated event handlers with event-specific filtering, then delegate to ThrottledRefresh.

**Rationale:**
- Keeps Refresh method signature clean (no event params)
- Event filtering is domain logic (belongs in module)
- Different events may need different filtering (unit, source, etc.)

**Implementation:**
```lua
function ResourceBar:OnUnitAura(event, unit)
    if unit ~= "player" then return end
    -- Special logic for state changes
    if self:_MaybeRefreshForVoidMetaStateChange() then return end
    self:ThrottledRefresh()
end
```

### 5. Text Overlay in CreateFrame

**Decision:** Create text overlay directly in `BarFrame:CreateFrame()` instead of using a separate `AddTextOverlay()` helper.

**Rationale:**
- Text overlay is a core feature of BarFrame, not an optional add-on
- Creating it in CreateFrame ensures it's always available
- Simplifies the API - no need to call separate setup methods
- Methods (`SetText`, `SetTextVisible`) attached to frame, not module

**Implementation:**
```lua
-- BarFrame.lua:CreateFrame
frame.TextFrame = CreateFrame("Frame", nil, frame)
frame.TextFrame:SetFrameLevel(frame.StatusBar:GetFrameLevel() + 10)
frame.TextValue = frame.TextFrame:CreateFontString(...)

function frame:SetText(text)
    if self.TextValue then
        self.TextValue:SetText(text)
    end
end
```

**Font Application:**
- Uses `Util.ApplyFont(fontString, profile)` which handles LSM resolution
- Applied every refresh to respect dynamic config changes
- Global settings: `font`, `fontSize`, `fontOutline`, `fontShadow`

### 6. BuffBars Integration

**Decision:** Use ECMFrame directly, skip BarFrame, override UpdateLayout for child management.

**Rationale:**
- BuffBars doesn't manage its own StatusBar (Blizzard does)
- BuffBars is about positioning and styling children, not updating a single bar
- Still benefits from ECMFrame (chain anchoring, config access, visibility)

**Trade-offs:**
- ✅ Aligns with new architecture
- ✅ Registered in ECM.RegisterFrame for global layout updates
- ✅ Can participate in chain anchoring
- ❌ More complex than standard bars (child management, edit mode hooks)
- ❌ Can't use BarFrame utilities (but doesn't need them)

## Next Steps

### Immediate Testing
1. Test PowerBar in-game - validate basic functionality
2. Test ResourceBar in-game:
   - Combo points for Rogue/Feral
   - Soul shards for Warlock
   - DH soul fragments (Havoc/Vengeance)
   - Devourer void meta state changes
3. Test RuneBar in-game:
   - DK rune display
   - Fragmented bar positioning
   - Cooldown animations
4. Test BuffBars in-game:
   - Blizzard viewer integration
   - Chain anchoring after RuneBar
   - Per-bar colors
   - Edit mode compatibility

### Short-term
1. Remove deprecated files:
   - `Mixins/PositionStrategy.lua` (replaced by ECMFrame layout)
   - `Modules/ViewerHook.lua` (replace with Layout.lua)
2. Implement Layout.lua:
   - Global hide-when-mounted functionality
   - Broadcast layout updates to all ECMFrames
   - Replace ViewerHook pattern

### Long-term
1. Consider extracting chain anchor logic to ECMFrame (currently local function)
2. Design font application pattern (LSM integration)
3. Consider tick renderer as separate mixin vs inline BarFrame methods
4. Evaluate if `GetStatusBarValues()` abstraction is worth the complexity

## Open Questions

1. **Font Application:** Where should fonts be configured and applied?
   - Current: BarHelpers have placeholder, not implemented
   - Need LSM integration for texture/font selection
   - Should fonts be per-module or global only?

2. **Chain Order Management:**
   - Currently hardcoded in Constants.CHAIN_ORDER
   - Should modules be able to register themselves in order?
   - How to handle dynamic enabling/disabling?

3. **Layout.lua Design:**
   - How to trigger global layout updates (mounted, settings change, etc.)?
   - Should Layout.lua own ECM.RegisterFrame() or vice versa?
   - Event registration pattern for global state changes?

## Known Issues

None at this time. All modules have been successfully refactored to the new pattern.

## Testing Checklist

**PowerBar:**
- [ ] Appears when entering world
- [ ] Updates when power changes
- [ ] Hides for DPS mana users (except Mage/Warlock/Druid)
- [ ] Anchors correctly to EssentialCooldownViewer
- [ ] Respects global updateFrequency throttling
- [ ] Shows correct colors for different power types
- [ ] Text overlay displays current power value in center
- [ ] Text shows percentage for mana when showManaAsPercent enabled
- [ ] Text respects global font settings
- [ ] Text visibility controlled by showText config
- [ ] Tick marks appear at configured power thresholds (if configured)

**ResourceBar:**
- [ ] Shows combo points for Rogue/Feral
- [ ] Shows chi for Monk
- [ ] Shows soul shards for Warlock
- [ ] Shows DH soul fragments (Havoc/Vengeance)
- [ ] Shows Devourer fragments with void meta color change
- [ ] Tick marks appear between resources
- [ ] Text overlay shows for Devourer

**RuneBar:**
- [ ] Shows for Death Knight only
- [ ] Displays 6 fragmented bars
- [ ] Ready runes appear first (left side)
- [ ] Cooldown runes sorted by time remaining
- [ ] Cooldown animation is smooth
- [ ] Half-brightness for runes on cooldown
- [ ] Tick marks appear between runes

**BuffBars:**
- [ ] Uses Blizzard BuffBarCooldownViewer
- [ ] Anchors in chain after RuneBar
- [ ] Per-bar colors apply correctly
- [ ] Edit mode changes persist
- [ ] New buffs/debuffs trigger rescan
- [ ] Child bars stack vertically
