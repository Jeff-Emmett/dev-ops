---
id: TASK-24
title: Export and import Google Passwords into KeePass
status: Done
assignee: []
created_date: '2026-02-13 22:00'
updated_date: '2026-02-13 21:12'
labels:
  - security
  - keepass
  - migration
dependencies:
  - task-22
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
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
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Google Passwords exported
- [ ] #2 Chrome passwords exported (if separate)
- [ ] #3 All passwords imported into KeePass vault
- [ ] #4 Entries deduplicated and organized into folders
- [ ] #5 CSV exports securely deleted
- [ ] #6 Import verified by spot-checking entries
- [ ] #7 Sync confirmed (vault updated on all devices)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Google Passwords exported via passwords.google.com CSV, imported into KeePass vault. Vault grew from 30KB to 237KB. Synced to Netcup. Plaintext CSV deleted from Downloads.
<!-- SECTION:NOTES:END -->

## Notes
