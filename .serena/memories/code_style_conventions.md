# Code Style and Conventions

## Formatting
- **Indent**: 4 spaces (no tabs)
- **Charset**: UTF-8
- **Final newline**: Yes
- **Trailing whitespace**: Trimmed

## Naming Conventions
- **Modules**: PascalCase (e.g., `PowerBars`, `SegmentBar`)
- **Methods**: PascalCase with colon (e.g., `PowerBars:Refresh()`)
- **Functions**: PascalCase (e.g., `GetPrimaryResourceValue`)
- **Local variables**: camelCase (e.g., `displayValue`, `valueType`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `TRACE_LOG_MAX`, `MIN_BAR_WIDTH`)
- **Private fields**: Underscore prefix (e.g., `self._frame`, `self._externallyHidden`)

## Module Pattern
- Use `LibStub("AceAddon-3.0"):GetAddon("EnhancedCooldownManager")` to get addon reference
- Create modules via `addon:NewModule("ModuleName", "AceEvent-3.0")`
- Access namespace via `local _, ns = ...`

## Error Handling
- Use `assert()` / `error()` with clear messages for internal invariants
- Use `pcall` for Blizzard/third-party frames where methods may not exist
- Do NOT use `type(x) == "function"` guards except for future-update APIs

## Code Guidelines
- Implement EXACTLY and ONLY what is requested
- Do not reach into another module's internals
- Remove unused code; minimize duplication via shared helpers in `Utilities.lua`
- **Do NOT use upvalue caching** (e.g., `local math_floor = math.floor`)
- ALWAYS prefer editing existing files over creating new ones

## Secret Value Handling (WoW-specific)
Many Blizzard API values are "secret" and cannot be compared or concatenated:
- Use `issecretvalue(v)` to check if a value is secret
- Use `canaccessvalue(v)` to check if you can safely use a value
- Pass to `SafeGetDebugValue()` for debug output
- AVOID: `C_UnitAuras.GetPlayerAuraBySpellID()`, `C_UnitAuras.GetUnitAuraBySpellID()`
