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

Installed (`requirements.txt`): **cadCAD 0.5.3**, **radCAD 0.14** (faster, cadCAD-compatible
engine), numpy, pandas, scipy, **networkx**; **matplotlib, plotly, seaborn, bokeh**; JupyterLab.

## JS (browser visualization)
`package.json` (installed via `bun install` → `node_modules/`):
**D3 7.9**, **three.js 0.170**, **@observablehq/plot 0.6.17**, topojson-client.

```js
import * as Plot from "@observablehq/plot";
import * as THREE from "three";
import * as d3 from "d3";
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
