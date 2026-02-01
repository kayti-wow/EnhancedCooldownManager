# Refactor Progress and Design Decisions

## Overview

This document tracks the ongoing refactor to establish a mixin-based architecture for Enhanced Cooldown Manager. The goal is to separate concerns cleanly across three layers:

- **ECMFrame**: Frame lifecycle, layout, positioning, borders, config access
- **BarFrame**: StatusBar management, values, colors, textures
- **Concrete Modules** (PowerBar, ResourceBar, RuneBar): Event handling, domain logic

## Architecture

### Mixin Hierarchy

```
ECMFrame (base) -> BarFrame (bar specialization) -> PowerBar/ResourceBar/RuneBar (concrete)
ECMFrame (base) -> BuffBars (specialized)
```

### Responsibility Separation

**ECMFrame** (`Mixins/ECMFrame.lua`)
- Owns: Inner WoW frame, layout (positioning, anchor, border, background), config access, visibility control
- Public API: `GetInnerFrame()`, `GetGlobalConfig()`, `GetConfigSection()`, `ShouldShow()`, `UpdateLayout()`, `SetHidden()`, `Refresh(force)`
- Internal state: `_innerFrame`, `_config`, `_configKey`, `_layoutCache`, `_hidden`

**BarFrame** (`Mixins/BarFrame.lua`)
- Owns: StatusBar creation, value updates, appearance (texture, colors)
- Public API: `CreateFrame()`, `GetStatusBarValues()` (abstract), `ThrottledRefresh()`, `Refresh(force)`
- Internal state: `_lastUpdate`
- Future: Text overlay, tick rendering (currently commented out)

**PowerBar** (`Bars/PowerBar.lua`)
- Owns: Event registration, power-specific value calculations, class/spec visibility rules
- Implements: `GetStatusBarValues()`, `ShouldShow()`, `Refresh(event, unitID)` (event filtering)
- Events: `UNIT_POWER_UPDATE` -> `ThrottledRefresh`

### Configuration Access Pattern

Modules access config through ECMFrame methods:
- `self:GetGlobalConfig()` - Returns `db.profile.global`
- `self:GetConfigSection()` - Returns `db.profile[configKey]` (e.g., `db.profile.powerBar`)
- Config key derived from module name: "PowerBar" -> "powerBar" (camelCase)

### Chain Anchoring

Bars anchor in fixed order: PowerBar -> ResourceBar -> RuneBar

- First visible bar anchors to `EssentialCooldownViewer`
- Subsequent bars anchor to previous visible bar in chain
- `GetNextChainAnchor()` walks backwards to find first visible predecessor
- Chain mode uses dual-point anchoring (TOPLEFT/TOPRIGHT) to inherit width

## MVP Status: PowerBar

### Completed (2026-02-01)

**Critical Bug Fixes:**
1. ✅ Fixed syntax error in `ECMFrame.lua:286` - Completed truncated `self:Refresh(force)` call, removed undefined `force` parameter
2. ✅ Fixed `ECMFrame.lua:84` - Changed `GetModuleByName()` to `GetModule(name, true)` (method didn't exist)
3. ✅ Fixed `ECMFrame.lua:86` - Changed `GetBarFrame()` to `GetInnerFrame()` (method didn't exist)
4. ✅ Fixed `BarFrame.lua:286` - Removed undefined `unitID`/`event` variable references
5. ✅ Fixed `BarFrame.lua:323` - Changed `ECM.Log()` to `Util.Log()`, `self:GetName()` to `self.Name`
6. ✅ Fixed `PowerBar.lua:133,136` - Swapped return order from `max, current` to `current, max` (matched BarFrame expectations)

**Refactoring:**
1. ✅ Removed text overlay calls from `BarFrame:Refresh()` - Text functionality commented out, will be restored later
2. ✅ Created `PowerBar:OnUnitPowerUpdate(event, unitID)` - Dedicated event handler with unitID filtering (domain-specific)
3. ✅ Commented out `PowerBar:UpdateTicks()` - Tick rendering not yet implemented in new architecture
4. ✅ Changed event registration from `"ThrottledRefresh"` to `"OnUnitPowerUpdate"` - Proper event handler pattern

**PowerBar MVP Features:**
- ✅ Frame creation via ECMFrame/BarFrame mixins
- ✅ Layout and positioning (chain anchoring)
- ✅ Border and background rendering
- ✅ StatusBar value updates (current/max power)
- ✅ Power type color mapping
- ✅ Texture application
- ✅ Event handling (UNIT_POWER_UPDATE)
- ✅ Throttled refresh (respects global updateFrequency)
- ✅ Class/spec visibility rules (hide mana for DPS except Mage/Warlock/Druid)
- ✅ Mana percentage display option

### Deferred (Not in MVP)

**Text Overlay:**
- Status: Commented out in BarFrame (lines 33-81)
- Reason: Need to design where text creation happens (CreateFrame? AddMixin? Module-specific?)
- TODO: Restore `BarFrame.AddTextOverlay()` or integrate into CreateFrame flow
- Note: Font application placeholder exists but not implemented

**Tick Rendering:**
- Status: Commented out in BarFrame (lines 87-246)
- Reason: Need to decide on TickRenderer pattern vs inline methods
- TODO: Design tick pool management, decide if separate mixin or BarFrame responsibility
- PowerBar has tick config (`GetCurrentTicks()`) ready for when implemented

## Design Decisions

### 1. Event Filtering in Dedicated Event Handlers

**Decision:** Event-specific logic (e.g., `unitID ~= "player"`) belongs in dedicated event handlers, not in Refresh methods.

**Rationale:**
- BarFrame.Refresh is generic - shouldn't know about WoW-specific event parameters
- Different modules may have different filtering needs
- PowerBar only cares about player unit, but ResourceBar might have different rules
- Keeps Refresh method signature clean - can be called directly without event params
- Event handlers filter and delegate to ThrottledRefresh

**Implementation:**
```lua
-- PowerBar.lua
function PowerBar:OnUnitPowerUpdate(event, unitID, ...)
    if unitID and unitID ~= "player" then
        return
    end
    self:ThrottledRefresh()
end

-- In OnEnable:
self:RegisterEvent("UNIT_POWER_UPDATE", "OnUnitPowerUpdate")
```

### 2. Text Overlay Deferred

**Decision:** Remove text overlay calls from BarFrame.Refresh for MVP. Will restore later with proper architecture.

**Rationale:**
- Need to decide where text frames are created (CreateFrame? AddMixin? Module override?)
- Font application needs design (LSM integration, config binding)
- StatusBar functionality is sufficient for MVP validation

**Future Work:**
- Restore `BarFrame.AddTextOverlay(bar, profile)` or integrate into CreateFrame
- Decide if text is always present or optional per-module
- Design font config access pattern

### 3. Tick Rendering Deferred

**Decision:** Comment out tick functionality for MVP.

**Rationale:**
- Tick pooling, positioning, and lifecycle is complex
- PowerBar's tick config is class/spec-specific (not needed for basic validation)
- StatusBar alone is sufficient to validate mixin architecture

**Future Work:**
- Restore commented methods or create separate TickRenderer mixin
- Decide: inline methods on BarFrame vs separate mixin pattern
- PowerBar has `GetCurrentTicks()` ready for integration

### 4. GetInnerFrame vs GetBarFrame

**Decision:** Use `GetInnerFrame()` everywhere. No `GetBarFrame()` alias needed.

**Rationale:**
- Single method reduces confusion
- "InnerFrame" clearly indicates it's the WoW Frame object owned by ECMFrame
- No semantic difference between the two names in current architecture

### 5. Config Key Derivation

**Decision:** Auto-derive config key from module name: "PowerBar" -> "powerBar" (camelCase).

**Implementation:** `ECMFrame.AddMixin` (line 326)
```lua
target._configKey = name:sub(1,1):lower() .. name:sub(2)
```

**Trade-offs:**
- ✅ DRY - no need to specify config key separately
- ✅ Enforces naming convention
- ❌ Fragile - assumes module name matches config structure
- ❌ Magic - not immediately obvious without reading mixin code

**Alternative Considered:** Explicit config key parameter in AddMixin
**Why Rejected:** Current codebase follows strict naming convention, unlikely to deviate

## Next Steps

### Immediate (Post-MVP)
1. Test PowerBar in-game - validate all fixes work
2. Restore text overlay functionality with proper design
3. Restore tick rendering functionality

### Short-term
1. Refactor ResourceBar to use new mixin architecture
2. Refactor RuneBar to use new mixin architecture
3. Test chain anchoring with all three bars enabled

### Long-term
1. Refactor BuffBars to use ECMFrame (no BarFrame, different child structure)
2. Remove PositionStrategy.lua (replaced by ECMFrame layout)
3. Remove ViewerHook.lua (replaced by Layout.lua)
4. Design and implement global hide-when-mounted functionality in Layout.lua

## Open Questions

1. **Font Application:** Where should fonts be configured and applied?
   - Per-module config or global?
   - Applied in CreateFrame, UpdateLayout, or Refresh?
   - Should text frames be created unconditionally or only when showText=true?

2. **Tick Renderer Design:**
   - Separate mixin (TickRenderer.AttachTo) or inline BarFrame methods?
   - Should tick pools be per-module or per-frame?
   - How to handle different tick types (resource dividers vs value markers)?

3. **Refresh Override Pattern:**
   - Should all modules override Refresh for event filtering?
   - Or should ThrottledRefresh accept event params and filter before calling Refresh?
   - Current: Modules override Refresh, BarFrame.Refresh is "clean"

4. **Layout Cache Persistence:**
   - Should _layoutCache be cleared on config changes?
   - How to detect config changes vs layout recalculation?
   - Currently: Change detection on every UpdateLayout call

## Known Issues

None at this time. All critical bugs blocking PowerBar have been fixed.

## Testing Notes

**Manual Testing Checklist:**
- [ ] PowerBar appears when entering world
- [ ] PowerBar updates when power changes
- [ ] PowerBar hides for DPS mana users (except Mage/Warlock/Druid)
- [ ] PowerBar anchors correctly to EssentialCooldownViewer
- [ ] PowerBar respects global updateFrequency throttling
- [ ] PowerBar shows correct colors for different power types
- [ ] PowerBar respects enabled/disabled config
- [ ] PowerBar respects border config (thickness, color, enabled)
- [ ] PowerBar respects background color config
- [ ] Mana percentage option works correctly
