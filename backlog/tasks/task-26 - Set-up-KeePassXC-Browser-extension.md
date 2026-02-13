---
id: task-26
title: Set up KeePassXC-Browser extension
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, browser]
priority: medium
dependencies: [task-22]
---

## Description

Install and configure the KeePassXC-Browser extension for Chrome/Firefox to enable seamless autofill of credentials from the KeePass vault.

## Plan

1. Enable browser integration in KeePassXC
   - Tools → Settings → Browser Integration → Enable
   - Select browser(s): Chrome, Firefox
2. Install KeePassXC-Browser extension
   - Chrome Web Store / Firefox Add-ons
3. Connect extension to KeePassXC
   - Click extension icon → Connect
   - KeePassXC will prompt to allow the connection
   - Assign a name (e.g., "Chrome-WSL2")
4. Configure extension settings:
   - Auto-fill on page load: OFF (security — only fill on click)
   - Show notifications: ON
   - Match URLs by: hostname (not full URL)
5. Test with multiple sites
6. Optionally disable Chrome's built-in password manager
   - Chrome → Settings → Passwords → Offer to save: OFF

## Acceptance Criteria

- [ ] KeePassXC browser integration enabled
- [ ] Extension installed in primary browser
- [ ] Extension connected and authenticated
- [ ] Auto-fill working on test sites
- [ ] Chrome's built-in password save disabled
- [ ] Extension configured securely (no auto-fill on load)

## Notes

- KeePassXC must be running and unlocked for the extension to work
- The extension communicates via native messaging (no network, local socket only)
