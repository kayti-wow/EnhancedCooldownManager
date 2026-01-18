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

## Secret Values

In combat/instances, many Blizzard API returns are restricted. Cannot compare, convert type, or concatenate.

- `issecretvalue(v)` / `canaccessvalue(v)` to check
- `SafeGetDebugValue()` for debug output
- Avoid `C_UnitAuras` APIs using spellId; use `auraInstanceId` instead
