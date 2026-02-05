---
id: task-18
title: Self-host Whisper transcription (faster-whisper-server)
status: Done
assignee: []
created_date: '2026-02-05 16:53'
updated_date: '2026-02-05 16:53'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deploy self-hosted Whisper API to replace RunPod for all transcription services
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Deploy faster-whisper-server on Netcup RS 8000
- [x] #2 Configure with large-v3-turbo model
- [x] #3 Update voice.jeffemmett.com to use local whisper
- [x] #4 Update youtube-transcriber to use local whisper
- [x] #5 Update canvas-website worker to use local whisper
- [x] #6 Test all transcription endpoints
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed 2026-02-05:
- Deployed faster-whisper-server at whisper.jeffemmett.com
- Model: deepdml/faster-whisper-large-v3-turbo-ct2
- Performance: ~4x realtime on CPU (3.5s for 15s audio)
- Updated services: voice-command, youtube-transcriber, canvas-website
- Cost savings: ~$30-60/month (eliminates RunPod whisper costs)
<!-- SECTION:NOTES:END -->
