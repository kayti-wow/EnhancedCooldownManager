# Code Style

**Format**: 4-space indent, UTF-8, trim trailing whitespace  
**Naming**: PascalCase modules/methods, camelCase locals, UPPER_SNAKE constants, `_prefix` private fields

## Guidelines
- Implement EXACTLY what is requested
- Don't reach into other modules' internals
- Use `assert()`/`error()` for invariants; `pcall` for Blizzard frames
- No upvalue caching (`local math_floor = math.floor`)
- Remove unused code

## Secret Values (WoW-specific)
Many Blizzard API returns are restricted in combat/instances. Cannot compare, convert, or concatenate.
- `issecretvalue(v)` - check if secret
- `canaccessvalue(v)` - check if usable
- `SafeGetDebugValue()` - for debug output
- Avoid `C_UnitAuras` APIs using spellId; use `auraInstanceId` instead
