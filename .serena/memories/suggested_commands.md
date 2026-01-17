# Suggested Commands

## Development Workflow
No build step required. Changes are live-reloaded in WoW.

### In-Game Commands
```
/reload                    -- Reload UI to apply changes
/ecm on                    -- Enable the addon
/ecm off                   -- Disable the addon  
/ecm toggle                -- Toggle addon state
/ecm debug                 -- Toggle debug mode
```

### Git Commands (Windows)
```bash
git status                 -- Check current changes
git add .                  -- Stage all changes
git commit -m "message"    -- Commit staged changes
git push                   -- Push to remote
git pull                   -- Pull from remote
git log --oneline -10      -- View recent commits
git diff                   -- View unstaged changes
```

### File System Commands (Windows)
```bash
dir                        -- List directory contents
type <file>                -- Display file contents (like cat)
findstr /s "pattern" *.lua -- Search in files (like grep)
cd <path>                  -- Change directory
```

## API Documentation
- WoW API: https://www.townlong-yak.com/framexml/beta/Blizzard_APIDocumentation

## Testing
Manual testing in-game via `/reload`. No automated test framework.
