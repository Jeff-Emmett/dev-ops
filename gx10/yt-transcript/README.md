# yt-transcript (GX10)

Small YouTube → transcript service for rSpace Notebook. Runs on GX10 (spark)
because GX10's residential egress IP is **not** YouTube-bot-blocked (netcup's
datacenter IP is), and it reuses GX10's local parakeet/whisper ASR (`:8990`)
for the no-captions fallback.

- `server.py` — stdlib HTTP service. `POST /transcript {url}` (Bearer
  `YT_TRANSCRIPT_TOKEN`) → `{ok,title,text,source}`; `GET /health`.
- Deployed to `/opt/yt-transcript/server.py`, systemd `yt-transcript.service`,
  listens `0.0.0.0:8991` (reachable via tailscale `100.64.0.5:8991`).
- Token lives in `.token` (gitignored) + the systemd unit + Infisical rspace
  (`YT_TRANSCRIPT_TOKEN`, `YT_TRANSCRIPT_URL=http://100.64.0.5:8991`).

rSpace `server/mi-sources-ingest.ts::extractFromYouTube` POSTs here when
`YT_TRANSCRIPT_URL` is set.

Update: edit `server.py`, `scp` to `/opt/yt-transcript/`, `sudo systemctl restart yt-transcript`.
