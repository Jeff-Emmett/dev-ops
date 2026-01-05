---
id: task-16
title: Test Wireshark MCP Bluetooth sniffing capabilities
status: To Do
assignee: []
created_date: '2026-01-05 23:24'
labels:
  - mcp
  - bluetooth
  - wireshark
  - testing
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Test the Wireshark MCP server's Bluetooth analysis tools:
- Attach USB Bluetooth adapter to WSL2 via usbipd-win
- Test bluetooth_list_adapters
- Test bluetooth_scan for nearby devices
- Test bluetooth_capture for HCI traffic
- Test bluetooth_analyze on captured data
- Document any issues or improvements needed
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 USB Bluetooth adapter successfully attached to WSL2
- [ ] #2 bluetooth_list_adapters shows the adapter
- [ ] #3 bluetooth_scan discovers nearby devices
- [ ] #4 bluetooth_capture creates valid pcap file
- [ ] #5 bluetooth_analyze decodes HCI/L2CAP packets
<!-- AC:END -->
