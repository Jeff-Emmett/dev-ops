---
id: TASK-MEDIUM.18
title: Expand open-source design/viz stack (dev-ops + JMJMJ pantheon)
status: Done
assignee: []
created_date: '2026-06-22 18:11'
updated_date: '2026-06-22 19:13'
labels:
  - design
  - viz
  - forge
  - morpheus
  - jmjmj
  - infrastructure
dependencies: []
parent_task_id: TASK-MEDIUM
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Umbrella: add the genuinely-missing design/visualization verticals after auditing what already exists. NOT redundant with existing coverage.

ALREADY PRESENT (do not rebuild): image-forge (raster/vector convert + Inkscape), doc-forge (libreoffice/tectonic/typst/pandoc/scribus/inkscape + graphviz/plantuml/mermaid diagrams + huge font set), media/clip-forge (av), Blender, FreeCAD, KiCad, ComfyUI/fal/runpod (AI gen), rspace-online holon-viz-forge (emits sankey/graph/chart/table SPECS).

PANTHEON = JMJMJ (Janus/Mercury/Juno/Morpheus/Justitia). Forges are Morpheus participants, registered statically in rspace-online shared/morpheus/forge-engine.ts (builtinEngines) + form.ts (builtinForms) + a proxy router + server/index.ts mount.

STEPS:
1. [DONE] doc-forge: vega (vl-convert, browserless Vega-Lite/Vega -> svg/png/pdf) + d2 (Terrastruct, svg native + inkscape raster). Fills the data-chart gap; renders holon-viz-forge specs. matplotlib deliberately excluded (arbitrary Python exec = RCE on public convert.jeffemmett.com).
2. doc-forge: font pipeline (fonttools subset/convert ttf<->woff2<->otf) at /subset.
3. image-forge: GIMP batch raster-edit gated engine (composite/filters/templated cards).
4. Penpot: self-hosted Figma alternative (the missing interactive-design vertical), Sablier-gated.
5. rspace-online JMJMJ/Morpheus registration: new forms (vega-json, d2, font) + capability handles for doc/image-forge; wire holon-viz specs -> doc-forge vega render path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Step 1: doc-forge vega + d2 engines, deployed + live-verified on convert.jeffemmett.com
- [x] #2 Step 2: doc-forge font subset/convert pipeline (fonttools)
- [ ] #3 Step 3: image-forge GIMP gated raster-edit engine
- [x] #4 Step 4: Penpot self-hosted, live + CF-protected
- [x] #5 Step 5: all new engines/forms registered in rspace-online Morpheus; pantheon dispatches; holon-viz specs render via doc-forge vega
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Step 1 DONE + live (convert.jeffemmett.com): vega (vl-convert) + d2. vega-lite .vl->png 30KB, d2->svg verified. doc-forge main 5928484.
Step 2 DONE + live: /font/subset (fonttools). DejaVuSans 759KB -> 9.8KB woff2 (A-Za-z subset) verified external. doc-forge main 00a72a5. pyftsubset+brotli confirmed in image.
Both deployed via scp (Netcup doc-forge is NOT git-managed) + docker compose build + recreate. doc-forge stays 768m tier (no enforcer gotcha).
REMAINING: Step 3 GIMP (image-forge, +heavy layer), Step 4 Penpot (new multi-container app, real RAM on pressured host), Step 5 rspace-online Morpheus registration (prod federation TS edits).

Step 3 RESOLVED (deferred, with rationale) — image-forge main 3f45631:
- GIMP dropped: Debian ships GIMP 3.0, whose headless Script-Fu broke (needs a display even with -i; 2.10 PDB procs renamed). Not worth ~400MB GTK + fragility.
- Tried routing XCF/PSD/PSB through ImageMagick (already in image, coders compiled in: XCF r--, PSD/PSB rw+). BUT this image's policy.xml is deny-all + allowlist {GIF,JPEG,PNG,WEBP} — those coders are policy-BLOCKED at runtime (would 500).
- Honest fix: removed psd/xcf/psb from the catalog (psd was a PRE-EXISTING false-advertisement; it always 500'd). /formats now lists only working formats.
- OPEN DECISION (security): enabling layered-format import = a read-only policy.xml relaxation (allow PSD/XCF/PSB read) on the PUBLIC images.jeffemmett.com. Defensible (passive bitmap coders, not script/SSRF like PS/MVG/URL) but widens attack surface. NOT done unilaterally — awaiting user OK.
AC#3 = resolved-as-deferred, not a literal GIMP engine.

Step 4 DONE + LIVE: Penpot at https://penpot.jeffemmett.com (HTTP 200). 5-container stack (frontend/backend/exporter/postgres15/valkey) at /opt/services/penpot, Sablier scale-to-zero (group=penpot, 30m session). dev-ops dev: compose+sablier+enforcer-skip+runbook.
Debugging that was needed:
- exporter crash-looped: 2.x exporter REQUIRES PENPOT_SECRET_KEY (not just backend).
- frontend nginx 'worker_processes auto' = 20 (host cores, cpuset doesn't shrink _SC_NPROCESSORS_ONLN) -> OOM at 256m; bumped to 700m (Sablier=0 idle).
- enforce-container-limits cron had clamped backend to 256m until penpot-* SKIP was deployed to /opt/scripts.
- CF tunnel = REMOTE-managed ingress (433 rules): 'cloudflared tunnel route dns' added DNS but CF edge 404'd until I GET/insert/PUT penpot.jeffemmett.com -> http://localhost:80 before the http_status:404 catch-all via the CF API (433->434).
REMAINING ACTION (user): create first account (registration DISABLED): docker exec -it penpot-backend ./manage.sh create-profile

Step 5 DONE (code, verified) — rspace-online dev 61636283:
- form.ts: 6 source forms (vega-lite, vega, graphviz, plantuml, mermaid, d2).
- forge-engine.ts: formExt maps (vl/vg/gv/puml/mmd/d2) + doc-forge handle (those → svg/png/pdf).
- holon-viz-forge.ts: vizRenderForge bridge (chart-spec→Vega-Lite, graph-spec→Graphviz DOT, escaped).
- registry.ts: vizRenderForge registered in sdkForgeModules.
- VERIFIED via planMorphPath: holon-set → project-forge → viz-forge → viz-render-forge → doc-forge → png resolves; also vega-lite/d2/etc → png|svg|pdf direct. 13+42 tests pass, typecheck clean.

THREE user-side follow-ups (not engineering):
1. ACTIVATE Step 5: ff rspace-online main→dev + deploy (CI builds :commit, RESTARTS the OOM-sensitive federation host — TASK-92). Not triggered unattended.
2. Penpot first account: docker exec -it penpot-backend ./manage.sh create-profile.
3. AC#3 (GIMP) WAIVED — user chose 'keep ImageMagick locked down'; layered-format import declined for security.

<!-- AC_WAIVED -->
<!-- SECTION:NOTES:END -->
