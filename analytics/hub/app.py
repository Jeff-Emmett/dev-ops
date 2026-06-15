"""Analytics Hub — network-wide rollup over Umami's Postgres (read-only).

Aggregates visitors / pageviews / trends + top sites + referrers + search
sources + countries across every Umami website, in one dashboard.
No API password needed: connects with the umami_ro least-privilege role.
"""
import os
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, Query
from fastapi.responses import HTMLResponse, JSONResponse

DATABASE_URL = os.environ["DATABASE_URL"]

# Search-engine referrer domains we treat as "organic search".
SEARCH_ENGINES = (
    "google.", "bing.", "duckduckgo.", "yahoo.", "ecosia.", "baidu.",
    "yandex.", "brave.", "startpage.", "qwant.", "search.", "kagi.",
)

pool: asyncpg.Pool | None = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=4)
    yield
    await pool.close()


app = FastAPI(title="Analytics Hub", lifespan=lifespan)


@app.get("/healthz")
async def healthz():
    async with pool.acquire() as c:
        await c.fetchval("SELECT 1")
    return {"ok": True}


@app.get("/api/summary")
async def summary(days: int = Query(30, ge=1, le=365)):
    async with pool.acquire() as c:
        # Per-site totals (only sites with traffic in window, plus names).
        sites = await c.fetch(
            """
            SELECT w.website_id, w.name, w.domain,
                   COUNT(*) FILTER (WHERE e.event_type = 1) AS pageviews,
                   COUNT(DISTINCT e.session_id)            AS visitors
            FROM website w
            LEFT JOIN website_event e
              ON e.website_id = w.website_id
             AND e.created_at >= now() - ($1 * interval '1 day')
            WHERE w.deleted_at IS NULL
            GROUP BY w.website_id, w.name, w.domain
            ORDER BY pageviews DESC
            """,
            days,
        )

        trend = await c.fetch(
            """
            SELECT date_trunc('day', created_at)::date AS day,
                   COUNT(*) FILTER (WHERE event_type = 1) AS pageviews,
                   COUNT(DISTINCT session_id)             AS visitors
            FROM website_event
            WHERE created_at >= now() - ($1 * interval '1 day')
            GROUP BY day ORDER BY day
            """,
            days,
        )

        referrers = await c.fetch(
            """
            SELECT referrer_domain AS source, COUNT(*) AS hits
            FROM website_event
            WHERE event_type = 1
              AND created_at >= now() - ($1 * interval '1 day')
              AND referrer_domain IS NOT NULL AND referrer_domain <> ''
              AND referrer_domain <> hostname
            GROUP BY referrer_domain ORDER BY hits DESC LIMIT 20
            """,
            days,
        )

        utm = await c.fetch(
            """
            SELECT utm_source AS source, COUNT(*) AS hits
            FROM website_event
            WHERE event_type = 1
              AND created_at >= now() - ($1 * interval '1 day')
              AND utm_source IS NOT NULL AND utm_source <> ''
            GROUP BY utm_source ORDER BY hits DESC LIMIT 15
            """,
            days,
        )

        countries = await c.fetch(
            """
            SELECT country, COUNT(DISTINCT session_id) AS visitors
            FROM session
            WHERE created_at >= now() - ($1 * interval '1 day')
              AND country IS NOT NULL AND country <> ''
            GROUP BY country ORDER BY visitors DESC LIMIT 12
            """,
            days,
        )

    refs = [dict(r) for r in referrers]
    search = [r for r in refs if any(s in (r["source"] or "") for s in SEARCH_ENGINES)]
    other_refs = [r for r in refs if r not in search]

    total_pv = sum(s["pageviews"] for s in sites)
    total_vis = sum(s["visitors"] for s in sites)

    return JSONResponse({
        "days": days,
        "totals": {
            "pageviews": total_pv,
            "visitors": total_vis,
            "active_sites": sum(1 for s in sites if s["pageviews"] > 0),
            "tracked_sites": len(sites),
        },
        "sites": [dict(s) for s in sites if s["pageviews"] > 0],
        "trend": [dict(t) | {"day": t["day"].isoformat()} for t in trend],
        "search": search[:12],
        "referrers": other_refs[:15],
        "campaigns": [dict(u) for u in utm],
        "countries": [dict(c) for c in countries],
    })


@app.get("/", response_class=HTMLResponse)
async def index():
    return HTMLResponse(INDEX_HTML)


INDEX_HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Analytics Hub</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
  :root{
    --bg:#0b0d12; --panel:#12151c; --panel2:#171b24; --line:#222836;
    --ink:#e8ecf4; --muted:#8a93a6; --accent:#5b8cff; --accent2:#34d399;
    --radius:14px;
  }
  *{box-sizing:border-box}
  body{margin:0;background:radial-gradient(1200px 600px at 80% -10%,#16203a 0,var(--bg) 55%);
    color:var(--ink);font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Inter,sans-serif;
    -webkit-font-smoothing:antialiased;padding:28px clamp(16px,4vw,48px) 64px}
  header{display:flex;align-items:baseline;gap:16px;flex-wrap:wrap;margin-bottom:24px}
  h1{font-size:22px;margin:0;letter-spacing:-.02em;font-weight:650}
  .sub{color:var(--muted);font-size:13px}
  .seg{margin-left:auto;display:flex;gap:4px;background:var(--panel);border:1px solid var(--line);
    border-radius:10px;padding:4px}
  .seg button{background:none;border:0;color:var(--muted);padding:6px 14px;border-radius:7px;
    cursor:pointer;font:inherit;font-size:13px}
  .seg button.on{background:var(--accent);color:#fff;font-weight:600}
  .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin-bottom:18px}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);padding:18px 20px}
  .card .k{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.06em}
  .card .v{font-size:32px;font-weight:700;letter-spacing:-.02em;margin-top:6px}
  .grid{display:grid;grid-template-columns:1fr;gap:14px}
  @media(min-width:980px){.grid{grid-template-columns:2fr 1fr}}
  .panel{background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);padding:18px 20px}
  .panel h2{font-size:13px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);
    margin:0 0 14px;font-weight:600}
  table{width:100%;border-collapse:collapse;font-size:14px}
  td{padding:7px 0;border-bottom:1px solid var(--line)}
  tr:last-child td{border-bottom:0}
  td.n{text-align:right;color:var(--muted);font-variant-numeric:tabular-nums;white-space:nowrap}
  .name{font-weight:550}.dom{color:var(--muted);font-size:12px}
  .two{display:grid;gap:14px;grid-template-columns:1fr}
  @media(min-width:640px){.two{grid-template-columns:1fr 1fr}}
  .bar{height:6px;border-radius:4px;background:var(--accent);opacity:.55;margin-top:4px}
  .pill{display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--accent2);margin-right:8px}
  .empty{color:var(--muted);font-size:13px;padding:8px 0}
  canvas{max-height:260px}
</style>
</head>
<body>
<header>
  <h1>Analytics Hub</h1>
  <span class="sub" id="sub">privacy-first network rollup · Umami</span>
  <div class="seg" id="seg">
    <button data-d="7">7d</button>
    <button data-d="30" class="on">30d</button>
    <button data-d="90">90d</button>
  </div>
</header>

<div class="cards" id="cards"></div>

<div class="grid">
  <div class="panel"><h2>Visitor & pageview trend</h2><canvas id="trend"></canvas></div>
  <div class="panel"><h2>Top sites</h2><table id="sites"></table></div>
</div>

<div class="two" style="margin-top:14px">
  <div class="panel"><h2><span class="pill"></span>Organic search</h2><table id="search"></table></div>
  <div class="panel"><h2>Referrers</h2><table id="referrers"></table></div>
</div>
<div class="two" style="margin-top:14px">
  <div class="panel"><h2>Campaign sources (UTM)</h2><table id="campaigns"></table></div>
  <div class="panel"><h2>Top countries</h2><table id="countries"></table></div>
</div>

<script>
let chart, days = 30;
const fmt = n => n.toLocaleString();
const flag = cc => cc ? cc.toUpperCase().replace(/./g,c=>String.fromCodePoint(127397+c.charCodeAt())) : "";

function rows(el, data, render, empty){
  const t = document.getElementById(el);
  if(!data.length){ t.innerHTML = `<tr><td class="empty">${empty}</td></tr>`; return; }
  t.innerHTML = data.map(render).join("");
}

async function load(){
  document.getElementById("sub").textContent = "loading…";
  const r = await fetch(`/api/summary?days=${days}`);
  const d = await r.json();
  document.getElementById("sub").textContent =
    `privacy-first network rollup · ${d.totals.active_sites}/${d.totals.tracked_sites} sites active · last ${days}d`;

  document.getElementById("cards").innerHTML = [
    ["Visitors", d.totals.visitors],
    ["Pageviews", d.totals.pageviews],
    ["Active sites", d.totals.active_sites],
    ["Pages / visitor", d.totals.visitors ? (d.totals.pageviews/d.totals.visitors).toFixed(1) : "0"],
  ].map(([k,v]) => `<div class="card"><div class="k">${k}</div><div class="v">${typeof v==="number"?fmt(v):v}</div></div>`).join("");

  const max = Math.max(1, ...d.sites.map(s=>s.pageviews));
  rows("sites", d.sites.slice(0,12), s =>
    `<tr><td><div class="name">${s.name}</div><div class="dom">${s.domain||""}</div>
       <div class="bar" style="width:${Math.round(s.pageviews/max*100)}%"></div></td>
     <td class="n">${fmt(s.visitors)}<br><span class="dom">${fmt(s.pageviews)} pv</span></td></tr>`,
    "no traffic yet");

  rows("search", d.search, x=>`<tr><td>${x.source}</td><td class="n">${fmt(x.hits)}</td></tr>`,
    "no search referrals yet");
  rows("referrers", d.referrers, x=>`<tr><td>${x.source}</td><td class="n">${fmt(x.hits)}</td></tr>`,
    "no referrers yet");
  rows("campaigns", d.campaigns, x=>`<tr><td>${x.source}</td><td class="n">${fmt(x.hits)}</td></tr>`,
    "no UTM campaigns yet");
  rows("countries", d.countries, x=>`<tr><td>${flag(x.country)} ${x.country}</td><td class="n">${fmt(x.visitors)}</td></tr>`,
    "no geo data yet");

  const labels = d.trend.map(t=>t.day.slice(5));
  const ds = (key,color)=>({label:key,data:d.trend.map(t=>t[key]),borderColor:color,
    backgroundColor:color+"22",fill:true,tension:.35,pointRadius:0,borderWidth:2});
  if(chart) chart.destroy();
  chart = new Chart(document.getElementById("trend"),{
    type:"line",
    data:{labels,datasets:[ds("visitors","#5b8cff"),ds("pageviews","#34d399")]},
    options:{responsive:true,interaction:{mode:"index",intersect:false},
      plugins:{legend:{labels:{color:"#8a93a6",boxWidth:12}}},
      scales:{x:{grid:{display:false},ticks:{color:"#8a93a6",maxTicksLimit:8}},
              y:{grid:{color:"#222836"},ticks:{color:"#8a93a6"}}}}});
}

document.getElementById("seg").addEventListener("click", e=>{
  if(e.target.tagName!=="BUTTON") return;
  document.querySelectorAll(".seg button").forEach(b=>b.classList.remove("on"));
  e.target.classList.add("on"); days=+e.target.dataset.d; load();
});
load();
setInterval(load, 5*60*1000);
</script>
</body>
</html>"""
