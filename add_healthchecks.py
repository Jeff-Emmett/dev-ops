#!/usr/bin/env python3
"""
Add healthcheck blocks to docker-compose.yml files for 46 repositories.
Determines the correct port from traefik labels and uses wget (default) or curl (Python services).

Insertion rule: AFTER labels: section (or volumes: if no labels), BEFORE networks: section.
If networks: comes before labels:, insert after the last label line instead.
"""

import re
import os
import sys

BASE_DIR = "/home/jeffe/Github"

REPOS = [
    "Undernet.earth-website",
    "backlog-md",
    "bam-staging-website",
    "blender-automation",
    "books-website",
    "cadcad-website",
    "cal-jeffemmett",
    "crypto-commons-gather.ing-website",
    "crypto-commons-website-2.0",
    "cynthia-poetry-website",
    "decolonize-time-website",
    "email-relay",
    "flight-club-lol",
    "flights-search",
    "flow-funding",
    "funz-quest",
    "higgys-android-website",
    "hyperindex-system",
    "jeffiverse-website",
    "jefflix-website",
    "littlehive-shop",
    "lunar-calendar",
    "myc0punkz-website",
    "mycofi-earth-website",
    "mycostack-website",
    "mytmux-website",
    "nofi-website",
    "nusqool-replica",
    "personal-dashboard",
    "phomemo-label-tool",
    "portapower-website",
    "post-app-website-new",
    "psilo-cybernetics-website",
    "rNetwork-online",
    "rSpace-website",
    "rfunds-online",
    "rsocials-online",
    "rstack-online",
    "rwallet-online",
    "shifts-dance-clone",
    "sportyfin",
    "tino-ardez-website",
    "transcribe-app",
    "xhivart-mirror",
    "youtube-transcriber",
    "zoomcal-jeffemmett",
]

# Ports that typically indicate Python/Flask/FastAPI services (use curl)
PYTHON_PORTS = {5000, 8000, 8025, 8080}


def find_traefik_port(content, service_name):
    """Extract the traefik loadbalancer port from the main service's labels."""
    # Search within the service block only
    lines = content.split('\n')
    in_service = False
    for line in lines:
        svc_match = re.match(r'^  (\S[^:]*):$', line)
        if svc_match:
            if svc_match.group(1).strip() == service_name:
                in_service = True
                continue
            elif in_service:
                break
        if in_service:
            match = re.search(r'loadbalancer\.server\.port=(\d+)', line)
            if match:
                return int(match.group(1))
    # Fallback: search entire file
    match = re.search(r'loadbalancer\.server\.port=(\d+)', content)
    if match:
        return int(match.group(1))
    return None


def find_main_service(content):
    """Find the first service that has traefik labels (the main service)."""
    lines = content.split('\n')
    current_service = None
    in_services = False

    for line in lines:
        if line.strip() == 'services:':
            in_services = True
            continue
        if in_services:
            svc_match = re.match(r'^  (\S[^:]*):$', line)
            if svc_match:
                current_service = svc_match.group(1).strip()
            if current_service and 'traefik' in line and 'loadbalancer' in line:
                return current_service

    # Fallback: return first service
    for line in lines:
        svc_match = re.match(r'^  (\S[^:]*):$', line)
        if svc_match:
            return svc_match.group(1).strip()
    return None


def has_healthcheck(content, service_name):
    """Check if the service already has a healthcheck block."""
    lines = content.split('\n')
    in_service = False

    for line in lines:
        svc_match = re.match(r'^  (\S[^:]*):$', line)
        if svc_match:
            if svc_match.group(1).strip() == service_name:
                in_service = True
                continue
            elif in_service:
                break

        if in_service:
            if line.strip().startswith('healthcheck:'):
                return True

    return False


def determine_tool(port):
    """Determine whether to use wget or curl based on port."""
    if port in PYTHON_PORTS:
        return "curl"
    return "wget"


def build_healthcheck_block(port, tool, indent="    "):
    """Build the healthcheck YAML block."""
    if tool == "curl":
        return (
            f"{indent}healthcheck:\n"
            f"{indent}  test: [\"CMD\", \"curl\", \"-f\", \"http://127.0.0.1:{port}/\"]\n"
            f"{indent}  interval: 30s\n"
            f"{indent}  timeout: 10s\n"
            f"{indent}  retries: 3\n"
            f"{indent}  start_period: 15s"
        )
    else:
        return (
            f"{indent}healthcheck:\n"
            f"{indent}  test: [\"CMD\", \"wget\", \"--no-verbose\", \"--tries=1\", \"--spider\", \"http://127.0.0.1:{port}/\"]\n"
            f"{indent}  interval: 30s\n"
            f"{indent}  timeout: 10s\n"
            f"{indent}  retries: 3\n"
            f"{indent}  start_period: 15s"
        )


def find_insertion_point(content, service_name):
    """
    Find the line index where we should insert the healthcheck.

    Strategy:
    1. Find the service block boundaries
    2. Locate labels: and networks: sections within the service
    3. Insert AFTER labels: section and BEFORE networks: section
    4. If labels: comes after networks:, insert after the last label line
    5. If no labels:, insert after volumes: section
    6. Fallback: insert before networks:
    """
    lines = content.split('\n')
    in_service = False
    service_end = None  # line index where the service block ends

    # Track positions of key sections within the service
    labels_start = None
    labels_end = None  # line after last label entry
    networks_start = None
    volumes_start = None
    volumes_end = None

    for i, line in enumerate(lines):
        # Detect service boundaries
        svc_match = re.match(r'^  (\S[^:]*):$', line)
        if svc_match:
            if svc_match.group(1).strip() == service_name:
                in_service = True
                continue
            elif in_service:
                service_end = i
                break

        # Top-level keys end the service block
        if in_service and re.match(r'^[a-zA-Z]', line) and ':' in line:
            service_end = i
            break

        if in_service:
            # Detect service-level properties (4-space indent)
            if re.match(r'^    labels:', line):
                labels_start = i
            elif re.match(r'^    networks:', line):
                networks_start = i
            elif re.match(r'^    volumes:', line):
                volumes_start = i

    if in_service and service_end is None:
        service_end = len(lines)

    # Now find the end of the labels section (first line that is a different service-level property after labels)
    if labels_start is not None:
        labels_end = labels_start + 1
        for i in range(labels_start + 1, service_end if service_end else len(lines)):
            line = lines[i]
            # Still in labels if line is indented more than 4 spaces (label entries at 6+ spaces)
            # or if it's a continuation/comment within labels
            if line.strip() == '':
                # Empty line might be end of labels or just spacing
                labels_end = i
                break
            elif re.match(r'^    [a-zA-Z]', line) and not line.strip().startswith('-') and not line.strip().startswith('#'):
                # This is a new service-level property
                labels_end = i
                break
            elif re.match(r'^  [a-zA-Z]', line) and not re.match(r'^    ', line):
                # Back to service level or top level
                labels_end = i
                break
            else:
                labels_end = i + 1

    # Find end of volumes section similarly
    if volumes_start is not None:
        volumes_end = volumes_start + 1
        for i in range(volumes_start + 1, service_end if service_end else len(lines)):
            line = lines[i]
            if line.strip() == '':
                volumes_end = i
                break
            elif re.match(r'^    [a-zA-Z]', line) and not line.strip().startswith('-') and not line.strip().startswith('#'):
                volumes_end = i
                break
            elif re.match(r'^  [a-zA-Z]', line) and not re.match(r'^    ', line):
                volumes_end = i
                break
            else:
                volumes_end = i + 1

    # Decision logic:
    # Preferred: after labels, before networks
    if labels_start is not None and networks_start is not None:
        if labels_start < networks_start:
            # labels comes first, insert after labels and before networks
            return labels_end
        else:
            # networks comes before labels, insert after labels section end
            return labels_end
    elif labels_start is not None:
        # Has labels but no networks in service block
        return labels_end
    elif volumes_start is not None and networks_start is not None:
        # No labels, use volumes as anchor
        if volumes_start < networks_start:
            return volumes_end
        else:
            return volumes_end
    elif volumes_start is not None:
        return volumes_end
    elif networks_start is not None:
        # Only networks found, insert before it
        return networks_start
    else:
        # Last resort: insert at end of service block
        return service_end

    return None


def process_repo(repo_name):
    """Process a single repository's docker-compose.yml."""
    compose_path = os.path.join(BASE_DIR, repo_name, "docker-compose.yml")

    if not os.path.exists(compose_path):
        return {"repo": repo_name, "status": "SKIP", "reason": "No docker-compose.yml"}

    with open(compose_path, 'r') as f:
        content = f.read()

    # Find main service
    service_name = find_main_service(content)
    if not service_name:
        return {"repo": repo_name, "status": "SKIP", "reason": "No service found"}

    # Find traefik port
    port = find_traefik_port(content, service_name)
    if not port:
        return {"repo": repo_name, "status": "SKIP", "reason": "No traefik port found", "service": service_name}

    # Check if healthcheck already exists
    if has_healthcheck(content, service_name):
        return {"repo": repo_name, "status": "SKIP", "reason": "Healthcheck already exists", "service": service_name, "port": port}

    # Determine tool (wget vs curl)
    tool = determine_tool(port)

    # Build healthcheck block
    healthcheck = build_healthcheck_block(port, tool)

    # Find insertion point
    lines = content.split('\n')
    insert_idx = find_insertion_point(content, service_name)

    if insert_idx is None:
        return {"repo": repo_name, "status": "ERROR", "reason": "Could not find insertion point", "service": service_name, "port": port}

    # Insert the healthcheck block
    new_lines = lines[:insert_idx] + healthcheck.split('\n') + lines[insert_idx:]
    new_content = '\n'.join(new_lines)

    # Write back
    with open(compose_path, 'w') as f:
        f.write(new_content)

    return {"repo": repo_name, "status": "OK", "service": service_name, "port": port, "tool": tool}


def main():
    results = []
    ok_count = 0
    skip_count = 0
    error_count = 0

    print("=" * 80)
    print("ADDING HEALTHCHECKS TO DOCKER-COMPOSE FILES")
    print("=" * 80)
    print()

    for repo in REPOS:
        result = process_repo(repo)
        results.append(result)

        status = result["status"]
        if status == "OK":
            ok_count += 1
            print(f"  OK   | {result['repo']:40s} | service: {result['service']:25s} | port: {result['port']:5d} | tool: {result['tool']}")
        elif status == "SKIP":
            skip_count += 1
            reason = result.get("reason", "")
            svc = result.get("service", "N/A")
            port = result.get("port", "N/A")
            print(f"  SKIP | {result['repo']:40s} | {reason} (service: {svc}, port: {port})")
        else:
            error_count += 1
            print(f"  ERR  | {result['repo']:40s} | {result.get('reason', 'Unknown error')}")

    print()
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"  Total repos:      {len(REPOS)}")
    print(f"  Healthchecks added: {ok_count}")
    print(f"  Skipped:           {skip_count}")
    print(f"  Errors:            {error_count}")
    print()

    if ok_count > 0:
        print("Repos updated:")
        for r in results:
            if r["status"] == "OK":
                print(f"  - {r['repo']} ({r['service']} on port {r['port']}, using {r['tool']})")

    if skip_count > 0:
        print("\nRepos skipped:")
        for r in results:
            if r["status"] == "SKIP":
                print(f"  - {r['repo']}: {r.get('reason', '')}")

    if error_count > 0:
        print("\nRepos with errors:")
        for r in results:
            if r["status"] == "ERROR":
                print(f"  - {r['repo']}: {r.get('reason', '')}")


if __name__ == "__main__":
    main()
