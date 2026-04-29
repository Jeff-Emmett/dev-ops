# cadCAD Repo Inventory (2026-04-29)

Triage of all cadCAD-related repos and notes under `/home/jeffe/Github/`. Classification: **live**, **reference**, **archive**.

| Repo | Last commit | Class | Notes |
|------|-------------|-------|-------|
| `cadcad-jax` | 2026-04-29 | **live** | New JAX helper lib. Pushed to Gitea (private), `dev` branch. Foundation for new model work. |
| `cadcad-mcp-server` | 2026-04-29 | **live** | New MCP server. Pushed to Gitea, deployed on Netcup at `/opt/apps/cadcad-mcp/`. Auto-discovers models from mounted `/models`. |
| `cookiecutter-cadcad-model` | 2026-04-29 | **live** | Bootstrap template. Pushed to Gitea. Run via `cookiecutter /home/jeffe/Github/cookiecutter-cadcad-model`. |
| `cadcad-lab` | (no git) | **live** | Jupyter sidecar at https://cadcad-lab.jeffemmett.com/lab. JAX 0.6.2, radCAD 0.14, optax, full scientific stack. Container running, 88 MB idle. **Should be git-init'd and pushed to Gitea.** |
| `cadcad-discourse-forum` | 2026-04-13 | **live** | Discourse instance for cadCAD community. Active. |
| `cadcad-website` | 2026-04-02 | **live** | Marketing site, deployed as `cadcad-website` container on Netcup. ⚠️ 2 uncommitted local changes — review and commit. |
| `cadCAD` | 2025-11-22 | **reference** | BlockScience upstream fork (Python ≤3.9 only, JAX-incompatible). Kept as snapshot for the legacy engine API. Pinned 0.5.x. |
| `conviction-voting-cadcad` | 2025-11-22 | **reference** | Token engineering primitive. Useful as a model to port to JAX. Snapshot only. |
| `cadcadconsolidate` | 2025-11-22 | **reference** | TEC token-engineering toolkit (`abcurve.py`, `convictionvoting.py`, `hatch.py`). Useful as a porting target — these are exactly the kinds of models that benefit most from the cadcad-jax pattern. |

## Standalone notes (not repos)

| File | Recommendation |
|------|---------------|
| `/home/jeffe/Github/cadCAD-aragon-rescue-plan.md` | Move into `cadcad-lab/notes/` to consolidate cadCAD documentation |
| `/home/jeffe/Github/cadCAD-fund-rescue-coordination.md` | Same |

## Recommendations

- **No archives needed.** All 9 repos still have active or reference value.
- **Action items**:
  1. Commit the 2 uncommitted files in `cadcad-website` (or stash).
  2. `git init` `cadcad-lab` and push to Gitea — currently the lab config is only on Netcup at `/opt/apps/cadcad-lab/` and locally without version control.
  3. Move 2 rescue-plan markdown files into a `cadcad-lab/notes/` subdir to declutter `~/Github/` root.
  4. Port one of the `cadcadconsolidate` primitives (suggest `convictionvoting.py`) to JAX as the canonical migration example — proves the radCAD→JAX recipe on a real-world TEC model.

## Compounding effect

The 3 new repos (`cadcad-jax`, `cookiecutter-cadcad-model`, `cadcad-mcp-server`) form a tight stack:
- New models bootstrap from cookiecutter
- Inherit cadcad-jax as a dep
- Auto-discoverable by cadcad-mcp for agent queries
- CI template (`dev-ops/ci-templates/cadcad-app.yml`) provides equivalence + benchmark

Reference forks (`cadCAD`, `conviction-voting-cadcad`, `cadcadconsolidate`) are inputs to this pipeline — porting targets, not deployments.
