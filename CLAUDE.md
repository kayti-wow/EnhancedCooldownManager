# Enhanced Cooldown Manager

WoW addon: customizable resource bars anchored to Blizzard's Cooldown Manager viewers.

## Guidelines

- Implement EXACTLY and ONLY what is requested
- Don't reach into other modules' internals
- Use `assert()`/`error()` for invariants; `pcall` for Blizzard/third-party frames
- No `type(x) == "function"` guards except for `issecretvalue`, `canaccessvalue`
- No upvalue caching (e.g., `local math_floor = math.floor`)
- Config: `EnhancedCooldownManager.db.profile` with module subsections

## Architecture

Blizzard frames: `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`

Bar stack: `EssentialCooldownViewer` → `PowerBar` → `SegmentBar` → `BuffBarCooldownViewer`

Use `Util.GetPreferredAnchor(addon, excludeModule)` for anchor chaining.

**Module interface**: `:GetFrame()`, `:GetFrameIfShown()`, `:SetExternallyHidden(bool)`, `:UpdateLayout()`, `:Refresh()`, `:Enable()`/`:Disable()`

## Mixins (`Modules/Mixins/`)

Bar modules use shared mixins (function-based, not object-based):

- **BarFrame**: Frame creation, appearance, text/value display
- **ModuleLifecycle**: Enable/Disable, event registration, throttled refresh
- **TickRenderer**: Tick pooling and positioning (segment dividers, value markers)

Usage: `local BarFrame = ns.Mixins.BarFrame` then `BarFrame.Create(name, parent, height)`

New bar modules should use these mixins. Domain-specific logic (value sources, colors, visibility) stays in the module.

## Secret Values

In combat/instances, many Blizzard API returns are restricted. Cannot compare, convert type, or concatenate.

- `issecretvalue(v)` / `canaccessvalue(v)` to check
- `SafeGetDebugValue()` for debug output
- Avoid `C_UnitAuras` APIs using spellId; use `auraInstanceId` instead
