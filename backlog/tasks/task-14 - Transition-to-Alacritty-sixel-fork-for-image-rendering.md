---
id: task-14
title: Transition to Alacritty sixel fork for image rendering
status: To Do
assignee: []
created_date: '2025-12-15 04:59'
updated_date: '2025-12-15 05:00'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace stock Alacritty with ayosec/alacritty sixel fork to enable ueberzugpp image rendering in tmux. Stock Alacritty explicitly rejects image protocol support.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Backup current Alacritty config
- [ ] #2 Install Rust build dependencies
- [ ] #3 Clone and build ayosec/alacritty sixel branch
- [ ] #4 Replace system Alacritty with sixel build
- [ ] #5 Configure tmux passthrough for images
- [ ] #6 Test ueberzugpp image rendering in tmux
- [ ] #7 Document any config changes needed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Backup current config
   - cp ~/.config/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml.backup
   - Note current Alacritty version: alacritty --version

2. Ensure Rust toolchain is ready
   - rustup update stable
   - Install deps: sudo apt install cmake pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev python3

3. Clone and build sixel fork
   - git clone -b sixel https://github.com/ayosec/alacritty.git ~/Github/alacritty-sixel
   - cd ~/Github/alacritty-sixel
   - cargo build --release
   - Binary at: target/release/alacritty

4. Install the sixel build
   - Option A (replace system): sudo cp target/release/alacritty /usr/local/bin/alacritty-sixel
   - Option B (alias): Add alias to ~/.bashrc or ~/.zshrc
   - Update desktop entry if needed

5. Configure tmux for passthrough
   - Add to ~/.tmux.conf:
     set -g allow-passthrough on
     set -ga update-environment TERM
     set -ga update-environment TERM_PROGRAM
   - Reload: tmux source-file ~/.tmux.conf

6. Test ueberzugpp
   - ueberzugpp layer --silent --no-stdin --use-escape-codes -o sixel
   - Test with sample image in tmux session

7. Verify and document
   - Confirm images render in tmux panes
   - Note any config tweaks needed
   - Update this task with findings
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**Fork Status (as of Dec 2024):**
- ayosec/alacritty sixel branch is community-maintained
- May lag behind upstream Alacritty releases
- Alternative: Check if newer forks exist at github.com/alacritty/alacritty/network/members
- Consider: WezTerm as fallback if sixel fork becomes unmaintained

**Related:**
- ueberzugpp installed and working
- tmux passthrough needs configuration
<!-- SECTION:NOTES:END -->
