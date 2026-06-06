# modeling-viz — shared modeling + visualization stack

One place for complex-systems **modeling** (cadCAD / radCAD) and **visualization**
(D3, three.js, Observable Plot, plus the Python viz stack). Used across rSpace,
TEC retrospectives, token-engineering, and the rCal cone-of-possibility work.

## Python (simulation + analysis)
Isolated venv at `.venv` (avoids the system PEP-668 lock). Activate or call directly:

```bash
source .venv/bin/activate          # or: .venv/bin/python …
jupyter lab                        # kernel: "modeling-viz (cadCAD)"
```

Installed (`requirements.txt`):
- **Modeling** — **cadCAD 0.5.3**, **radCAD 0.14** (faster, cadCAD-compatible engine),
  **mesa 3.x** (agent-based modeling; complements cadCAD's state-update style),
  numpy, pandas, scipy, **networkx**.
- **Viz** — **matplotlib, plotly, seaborn, bokeh**; **HoloViz** stack:
  **holoviews** (declarative), **panel** (interactive dashboards/apps),
  **datashader** (rasterize millions of points); JupyterLab.

## JS (browser visualization)
`package.json` (installed via `bun install` → `node_modules/`):
**D3 7.9**, **three.js 0.170**, **@observablehq/plot 0.6.17**, topojson-client,
**deck.gl 9** (GPU layers — `ArcLayer`/`TripsLayer` for space-time trajectories),
**Vega-Lite 5** (+ vega, vega-embed; declarative complex charts),
**Cytoscape 3** (interactive in-browser network viz).

```js
import * as Plot from "@observablehq/plot";
import * as THREE from "three";
import * as d3 from "d3";
import { Deck } from "deck.gl";
import vegaEmbed from "vega-embed";
import cytoscape from "cytoscape";
```

## Headless render / viz smoke test
`render.mjs` opens any local viz HTML headless, screenshots it, and **exits
non-zero if the page logged a JS error** — so it doubles as CI for visualizations.
Uses the locally-pinned **Playwright** (devDependency, reuses `~/.cache/ms-playwright`
chromium), so it survives nvm version churn — no puppeteer/global-chromium needed.

```bash
bun run render path/to/viz.html [out.png] --wait=900 --w=1280 --h=900
# or: node render.mjs path/to/viz.html
```

## Technique references
- D3 gallery — https://observablehq.com/@d3/gallery
- Spiral plot (Archimedean; `θ = numSpirals·π·r`, time→arc-length, loop=period) —
  https://datavizcatalogue.com/methods/spiral_plot.html
- Condegram spiral (D3 v4 reference impl) —
  https://gist.github.com/arpitnarechania/027e163073864ef2ac4ceb5c2c0bf616
- Time-geography / space-time prism (the cone-of-possibility's spatial twin): Hägerstrand.

## Worked examples (see this repo's siblings)
- rCal possibility cone (canvas 2.5D + three.js 3D) lives in
  `long-now-book-of-time-application/supporting-media/cone-*.html` — conical-helix spiral,
  and a space-time cone with temporal-zoom spatial aggregation.

`notebooks/` for cadCAD models · `examples/` for JS viz snippets · `vendor/` for pinned refs.
