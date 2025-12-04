---
id: task-9
title: Finalize AutoHotkey shortcuts script
status: Done
assignee: ["@claude"]
created_date: '2025-12-04'
completed_date: '2025-12-04'
labels: [productivity, windows, automation]
priority: low
---

## Description

Reorganize and finalize the Windows AutoHotkey v2 productivity shortcuts script (`C:\Users\jeffe\shortcuts.ahk`).

## Plan

1. Review existing shortcuts.ahk file
2. Reorganize code with clear section headers
3. Add comprehensive comments and documentation
4. Fix Win+X to only close browser tabs (not terminal)
5. Update command palette to reflect changes

## Acceptance Criteria

- [x] Code organized into logical sections with clear headers
- [x] All utility functions grouped at the top
- [x] Comprehensive header comment explaining features and usage
- [x] All shortcuts documented with inline comments
- [x] Win+X only closes browser tabs, not terminal/other apps
- [x] Command palette text updated to match functionality

## Notes

### Changes Made (2025-12-04)

**Reorganization:**
- Added comprehensive file header with features list and usage instructions
- Grouped utility functions (AddRoundedCorners, BringToFront, IsPaletteVisible) into dedicated section
- Created clear sections: System Configuration, CapsLock Remapping, Browser Tab Navigation, Command Palette, App Launcher Shortcuts, System Shortcuts
- Separated app shortcuts into "Native Applications" and "Web Apps (Chrome App Mode)" subsections
- Added descriptive comments to every shortcut
- Renamed "Porkbun Domain Manager" to "Web Domains (Porkbun)"

**Bug Fixes:**
- Win+X now only closes browser tabs (Ctrl+W), no action on other apps
- Previously would Alt+F4 any non-browser app, risking accidental terminal closes
- Used left/right Win key specific handlers (`<#x`, `>#x`) to better intercept before Windows
- Added KeyWait to prevent Windows menu from opening

**File Location:** `C:\Users\jeffe\shortcuts.ahk` (Windows path via WSL: `/mnt/c/Users/jeffe/shortcuts.ahk`)

### Features Summary

1. **CapsLock Remapping**: Tap=Escape, Hold=Ctrl modifier
2. **Browser Tab Navigation**: Ctrl+Left/Right for tab switching
3. **Command Palette**: Win+/ shows all shortcuts overlay
4. **App Launchers**: Win+key combos for 15+ apps/sites
5. **System Shortcuts**: Smart close, clipboard history, etc.
6. **Keyboard Optimization**: Fastest repeat speed settings
