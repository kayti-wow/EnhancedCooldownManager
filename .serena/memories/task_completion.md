# Task Completion Checklist

## Before Committing
1. **Test in-game**: Run `/reload` in WoW to verify changes work
2. **Check for errors**: Look for Lua errors in chat or BugSack addon
3. **Verify functionality**: Test the specific feature/fix that was changed
4. **Check related features**: Ensure changes didn't break related functionality

## Code Quality Checks
- No unused variables or functions left behind
- No debug print statements left in code (unless intended)
- Code follows the style conventions (4-space indent, naming conventions)
- No backwards-compatibility hacks for removed code

## Common Issues to Verify
- Bar anchoring still works after layout changes
- Colors update correctly when switching specs
- Frames show/hide appropriately when mounted/in vehicles
- Text displays correctly with different font sizes

## No Automated Linting/Formatting
This project has no automated linting or formatting tools. Manual review is required.
