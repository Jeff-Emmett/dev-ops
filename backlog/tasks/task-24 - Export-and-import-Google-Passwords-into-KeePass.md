---
id: task-24
title: Export and import Google Passwords into KeePass
status: To Do
assignee: ''
created_date: '2026-02-13 22:00'
labels: [security, keepass, migration]
priority: medium
dependencies: [task-22]
---

## Description

Export all saved passwords from Google Password Manager and Chrome browser, import them into the KeePass vault, then verify and clean up.

## Plan

1. **Export from Google Passwords**
   - Go to `passwords.google.com` → Settings → Export passwords
   - Downloads as CSV (DANGER: plaintext!)
   - Immediately move CSV to RAM disk or encrypted location
2. **Export from Chrome browser** (if different from Google sync)
   - Chrome → Settings → Passwords → Export
   - Also CSV format
3. **Import into KeePassXC**
   - Database → Import → CSV
   - Map columns: URL, Username, Password, Name
   - Import into `Personal/` folder
4. **Deduplicate and organize**
   - Remove duplicate entries
   - Move entries to appropriate subfolders
   - Add notes/tags where helpful
5. **Securely delete CSV exports**
   - `shred -vfz -n 5 passwords.csv` (overwrite 5 times)
   - Or if on SSD: `rm` then TRIM (shred less effective on SSD)
6. **Verify import**
   - Spot-check 10+ entries against original
   - Test login with a few entries
7. **Disable Google Password saving** (optional, after browser extension set up)

## Security Warning

⚠️ The CSV export contains ALL passwords in PLAINTEXT. Handle with extreme care:
- Never store on cloud-synced folders
- Delete immediately after import
- Use RAM disk (`/dev/shm/`) if possible
- Never commit to git

## Acceptance Criteria

- [ ] Google Passwords exported
- [ ] Chrome passwords exported (if separate)
- [ ] All passwords imported into KeePass vault
- [ ] Entries deduplicated and organized into folders
- [ ] CSV exports securely deleted
- [ ] Import verified by spot-checking entries
- [ ] Sync confirmed (vault updated on all devices)

## Notes

