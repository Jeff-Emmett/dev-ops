#!/usr/bin/env python3
"""
Batch CI/CD migration script.
Generates the server-side and local-side commands for migrating repos to CI/CD.

Usage: python3 batch-migrate-ci.py
"""
import subprocess
import os
import json

GITHUB_DIR = os.path.expanduser("~/Github")
TEMPLATE_DIR = os.path.join(GITHUB_DIR, "dev-ops/ci-templates")
MIGRATE_SCRIPT = os.path.join(GITHUB_DIR, "dev-ops/scripts/migrate-to-ci.sh")

# Skip list: infrastructure, complex multi-service, no compose, or conflicts
SKIP = {
    # No compose on server
    "alertbaytrumpeter-website", "aunty-sparkles-website", "configuration",
    "conviction-voting-website", "encryptid-sdk", "fcdm-website-new-kt",
    "katheryn-website", "kindness-fund-website", "mycopunk-website",
    "personal-knowledge-management-network", "quartz-live", "rpubs-online",
    "rspace-website", "undernet.earth-website", "voice-command",
    # No build (third-party images or DB-first services)
    "fungiflows", "headscale-deploy", "open-notebook", "seafile-deploy", "umami",
    # Complex multi-service (first service is DB, not the app)
    "games-platform", "open-claw-iron", "p2pwiki", "payment-infra", "rfiles-online",
    # Domain conflicts or stale
    "jeffemmett-website-redesign",  # conflicts with canvas-website (jeffemmett.com)
    # Already migrated
    "canvas-website",
}

# Repos where first service in compose is not the right one to migrate
# These need manual handling
COMPLEX = {
    "cosmolocal-website",  # has n8n alongside the website
}

# Migration data: repo_name -> (deploy_path, service_name, domain, repo_name_for_registry)
# This will be populated from server data
MIGRATIONS = {}


def get_server_data():
    """Get migration data from Netcup server."""
    script = '''python3 << "PYEOF"
import yaml, os, re, subprocess, json

result = subprocess.run(
    ["docker", "exec", "gitea-db", "psql", "-U", "gitea", "-t", "-c",
     "SELECT r.lower_name FROM webhook w JOIN repository r ON w.repo_id = r.id WHERE w.is_active = true ORDER BY r.lower_name;"],
    capture_output=True, text=True
)
active = sorted(set(line.strip() for line in result.stdout.strip().split("\\n") if line.strip()))

data = {}
for name in active:
    for prefix in ["/opt/websites/", "/opt/apps/"]:
        compose_path = f"{prefix}{name}/docker-compose.yml"
        if os.path.exists(compose_path):
            try:
                with open(compose_path) as f:
                    d = yaml.safe_load(f)
                services = list(d.get("services", {}).keys())
                svc = services[0]
                svc_data = d["services"][svc]
                has_build = "build" in svc_data
                if not has_build:
                    break
                domain = "?"
                labels = svc_data.get("labels", [])
                for label in labels:
                    if isinstance(label, str) and "Host(" in label:
                        m = re.search(r"Host\\(` + "`" + r"([^` + "`" + r"]+)` + "`" + r"\\)", label)
                        if m:
                            domain = m.group(1)
                            break
                # Get current image name
                result2 = subprocess.run(
                    ["docker", "images", "--format", "{{.Repository}}:{{.Tag}}"],
                    capture_output=True, text=True
                )
                img_name = ""
                for line in result2.stdout.strip().split("\\n"):
                    if name.lower() in line.lower() or svc.lower() in line.lower():
                        if "gitea.jeffemmett.com" not in line:
                            img_name = line.strip()
                            break
                data[name] = {
                    "path": f"{prefix}{name}",
                    "service": svc,
                    "domain": domain,
                    "image": img_name,
                }
            except Exception as e:
                pass
            break
print(json.dumps(data))
PYEOF'''
    result = subprocess.run(
        ["ssh", "netcup-full", script],
        capture_output=True, text=True, timeout=60
    )
    return json.loads(result.stdout.strip())


def check_local_repo(name):
    """Check if repo exists locally with a Dockerfile."""
    repo_path = os.path.join(GITHUB_DIR, name)
    if not os.path.isdir(repo_path):
        # Try case variations
        for d in os.listdir(GITHUB_DIR):
            if d.lower() == name.lower():
                repo_path = os.path.join(GITHUB_DIR, d)
                break
    if not os.path.isdir(repo_path):
        return None
    if not os.path.isfile(os.path.join(repo_path, "Dockerfile")):
        return None
    # Check if already has CI
    if os.path.isdir(os.path.join(repo_path, ".gitea", "workflows")):
        return None
    return repo_path


def get_branch_and_remote(repo_path):
    """Get current branch and gitea remote name."""
    branch = subprocess.run(
        ["git", "-C", repo_path, "branch", "--show-current"],
        capture_output=True, text=True
    ).stdout.strip()

    # Check if origin points to gitea
    origin_url = subprocess.run(
        ["git", "-C", repo_path, "remote", "get-url", "origin"],
        capture_output=True, text=True
    ).stdout.strip()

    if "gitea" in origin_url:
        remote = "origin"
    else:
        # Check for gitea remote
        remotes = subprocess.run(
            ["git", "-C", repo_path, "remote"],
            capture_output=True, text=True
        ).stdout.strip().split("\n")
        remote = "gitea" if "gitea" in remotes else None

    # Get default branch name
    default_branch = "main"
    branches = subprocess.run(
        ["git", "-C", repo_path, "branch"],
        capture_output=True, text=True
    ).stdout
    if "master" in branches and "main" not in branches:
        default_branch = "master"

    return branch, remote, default_branch


if __name__ == "__main__":
    print("Fetching server data...")
    server_data = get_server_data()
    print(f"Found {len(server_data)} repos with active webhooks and builds\n")

    migratable = []
    skipped = []
    no_local = []
    complex_repos = []

    for name, info in sorted(server_data.items()):
        if name in SKIP:
            skipped.append(name)
            continue
        if name in COMPLEX:
            complex_repos.append(name)
            continue

        repo_path = check_local_repo(name)
        if not repo_path:
            no_local.append(name)
            continue

        branch, remote, default_branch = get_branch_and_remote(repo_path)
        if not remote:
            no_local.append(f"{name} (no gitea remote)")
            continue

        domain = info["domain"]
        health_url = f"https://{domain}/" if domain != "?" else "http://localhost:3000/"

        migratable.append({
            "name": name,
            "repo_path": repo_path,
            "deploy_path": info["path"],
            "service": info["service"],
            "domain": domain,
            "health_url": health_url,
            "image": info["image"],
            "branch": branch,
            "remote": remote,
            "default_branch": default_branch,
        })

    print(f"=== MIGRATABLE: {len(migratable)} repos ===")
    for m in migratable:
        print(f"  {m['name']:40s} {m['domain']:35s} {m['deploy_path']}")

    print(f"\n=== SKIPPED: {len(skipped)} repos ===")
    for s in skipped:
        print(f"  {s}")

    print(f"\n=== NO LOCAL REPO: {len(no_local)} ===")
    for n in no_local:
        print(f"  {n}")

    print(f"\n=== COMPLEX (manual): {len(complex_repos)} ===")
    for c in complex_repos:
        print(f"  {c}")

    # Output as JSON for the next step
    with open("/tmp/ci-migration-plan.json", "w") as f:
        json.dump(migratable, f, indent=2)
    print("\nMigration plan written to /tmp/ci-migration-plan.json")
    print(f"Total: {len(migratable)} repos to migrate")
