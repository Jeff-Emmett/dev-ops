---
id: task-19
title: ClipForge Phase 1 MVP - Deploy core pipeline
status: Done
assignee: []
created_date: '2026-02-08 13:12'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Self-hosted AI video clipper (Opus Clip alternative). Full pipeline: upload/YouTube → yt-dlp download → Whisper transcription → Ollama AI clip selection → FFmpeg extraction. Deployed at clip.jeffemmett.com. All 5 Docker services running: postgres, redis, backend (FastAPI), worker (ARQ), frontend (placeholder). Tested end-to-end successfully.
<!-- SECTION:DESCRIPTION:END -->
