---
id: TASK-MEDIUM.17
title: Add Inkscape as gated vector engine in image-forge
status: In Progress
assignee: []
created_date: '2026-06-22 16:56'
updated_date: '2026-06-22 17:11'
labels:
  - forge
  - image
  - inkscape
  - vector
  - infrastructure
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Inkscape 1.x headless CLI as a capability-gated engine inside image-forge — NOT a replacement for the fast cairosvg/rsvg SVG→raster path, and NOT overlapping the interactive scribus-novnc DTP sidecar.

ORIGIN: Discussion 2026-06-22 with Claude evaluating Inkscape as a headless addition to the open-source design stack. Follow-up to TASK-69 (image-forge), whose spec already listed 'rsvg / Inkscape — SVG → raster' but shipped only cairosvg/rsvg.

RATIONALE: cairosvg has known fidelity gaps (filters, blend modes, advanced CSS, text shaping); librsvg better but incomplete. Inkscape has the most complete open-source SVG engine AND is the only tool in the stack that does vector-format INTERCHANGE (PDF/AI/EPS/EMF/WMF/CDR → editable SVG) plus bitmap→vector tracing. Keep cairosvg/rsvg as default for simple svg→png/jpg/pdf (fast, Python-native, no subprocess).

GATING: route to Inkscape ONLY when (a) engine=inkscape explicitly requested, (b) output is a vector-interchange format (eps/ps/emf/dxf), (c) input is a vector format cairosvg/rsvg cannot read (pdf/ai/eps → svg), or (d) a high-fidelity flag is set. Never the default.

OPS CONSTRAINTS: Inkscape drags the full GTK stack (~1GB image, hundreds of MB idle RAM, slow cold start — boots whole app per invocation). Netcup is at 62GB/389 containers under constant swap pressure. Therefore: run via --shell persistent process to amortize startup, and gate the container with Sablier scale-to-zero. Do NOT let it idle resident.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Inkscape engine added to ENGINES catalog in image-forge/server.py with correct vector inputs/outputs (svg,pdf,eps,ps,emf,wmf,dxf,ai,cdr→svg,png,pdf,eps,ps,emf,dxf)
- [x] #2 _pick_engine keeps cairosvg/rsvg as default for svg→png/jpg/pdf; Inkscape selected ONLY via explicit override or vector-interchange/high-fidelity gates
- [x] #3 _convert_with implements an inkscape branch using inkscape --export-type / --actions, invoked headlessly (no display) via _run()
- [x] #4 Inkscape runs in --shell persistent mode (or documented spawn-per-job) to amortize ~1s+ cold start
- [x] #5 Dockerfile installs inkscape in runtime stage; /health and /formats report the inkscape engine
- [ ] #6 Container gated with Sablier scale-to-zero; not idle-resident (verified RAM after idle)
- [x] #7 Tests cover svg→eps and pdf→svg through the inkscape engine; default svg→png still routes to rsvg
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented on image-forge branch `dev` (commit fea14c6). Code + tests complete; 22 passed / 2 skipped (svg→eps, pdf→svg skip without the inkscape binary locally — routing tested both ways incl. simulated INKSCAPE_BIN).

DONE (AC 1-5,7):
- ENGINES['inkscape'] catalog (vector in/out)
- _pick_engine gates: interchange-out (eps/ps/emf/dxf), vector-in (pdf/eps/ps/ai/emf/wmf/dxf/cdr→svg/png/pdf), fidelity flag; svg→png/jpg/pdf STILL routes rsvg (non-regression test)
- _convert_with inkscape branch: headless via persistent 'inkscape --shell' (INKSCAPE_SHELL=1 default), spawn-per-job fallback; completion by output-file poll (no prompt parsing)
- /convert fidelity flag; /health marks inkscape OPTIONAL (absence does not degrade); /formats auto-includes it
- Dockerfile: inkscape in its own layer, --build-arg WITH_INKSCAPE=0 to drop, headless XDG dirs under /tmp
- mcp convert_image fidelity arg; README gated-engine section
- tests: TestInkscapeEngine (routing + conversions)

PENDING (AC 6 — deploy-gated, NOT done here):
- Build image on Netcup with WITH_INKSCAPE=1 and gate the container with Sablier scale-to-zero given the 62GB/389-container memory pressure; verify RAM after idle. Requires Netcup deploy + Sablier label wiring on images.jeffemmett.com. Recommend validating the --shell action syntax against the deployed Inkscape version on first run (export-plain-svg / export-width action names are 1.x; confirm point release).

AC#6 deploy artifacts shipped (image-forge dev e2b8cb0 + dev-ops dev 67356f4):
- Two-layer RAM strategy: (1) whole-container Sablier scale-to-zero — compose switched to house forge pattern (sablier.enable+group, traefik.enable=false); idle 15m → container Exited → 0 RAM, Inkscape image costs only disk. (2) warm-window idle-reaper kills the persistent inkscape --shell after INKSCAPE_IDLE_TIMEOUT=120s of no vector jobs (lock-safe, unit-tested with fake proc).
- netcup/traefik/config/sablier-image-forge.yml (file-provider router + Sablier middleware, 90s blocking timeout for GTK cold start).
- netcup/image-forge-sablier-deploy.md — live-migration runbook (safe ordering, verify, RAM-layering checks, Inkscape 1.x action-name first-run check, rollback).
- memory limit 1G→1500M for vector-render headroom.
- 25 passed / 2 skipped.

AC#6 STILL UNCHECKED: the 'verified RAM after idle' half needs the operator to actually run the migration on the live images.jeffemmett.com (brief planned route blip) and observe docker stats / Exited state. Everything codeable is done; this is the one remaining live-production step. Follow netcup/image-forge-sablier-deploy.md.
<!-- SECTION:NOTES:END -->
