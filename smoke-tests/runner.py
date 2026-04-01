#!/usr/bin/env python3
"""
Smoke test runner — CLI orchestrator for Playwright smoke tests.

Usage:
  python3 runner.py <site-name>           # Test a single site
  python3 runner.py --all                 # Test all sites
  python3 runner.py --all --dry-run       # Show what would be tested
  python3 runner.py <site-name> --no-alert  # Skip email on failure
  python3 runner.py <site-name> --post-deploy  # Called by webhook after deploy
"""
import argparse
import json
import os
import subprocess
import sys
import time
import yaml

SITES_YAML = os.path.join(os.path.dirname(__file__), 'sites.yaml')
RESULTS_FILE = '/tmp/smoke-results.json'
_DEFAULT_LOG_DIR = '/var/log/smoke-tests' if os.path.isdir('/var/log/smoke-tests') or os.getuid() == 0 else os.path.join(os.path.dirname(__file__), 'logs')
LOG_DIR = os.environ.get('SMOKE_LOG_DIR', _DEFAULT_LOG_DIR)


def load_sites():
    with open(SITES_YAML) as f:
        return yaml.safe_load(f)


def run_tests(site_name, config):
    """Run Playwright tests for a site. Returns (exit_code, duration_s, results_json)."""
    defaults = config.get('defaults', {})
    wait = defaults.get('wait_after_deploy', 0)

    if os.environ.get('SMOKE_POST_DEPLOY') and wait > 0:
        print(f"  Waiting {wait}s for container to stabilize...")
        time.sleep(wait)

    env = os.environ.copy()
    env['SMOKE_SITE'] = site_name

    start = time.time()
    result = subprocess.run(
        ['npx', 'playwright', 'test'],
        cwd=os.path.dirname(__file__),
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
    duration = time.time() - start

    # Try to parse JSON results
    results = None
    if os.path.exists(RESULTS_FILE):
        try:
            with open(RESULTS_FILE) as f:
                results = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            pass

    # Print stdout/stderr for logging
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    return result.returncode, duration, results


def write_log(site_name, exit_code, duration, output):
    """Append result to log directory."""
    os.makedirs(LOG_DIR, exist_ok=True)
    from datetime import datetime
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    status = 'PASS' if exit_code == 0 else 'FAIL'
    log_file = os.path.join(LOG_DIR, f'{site_name}_{ts}_{status}.log')
    with open(log_file, 'w') as f:
        f.write(f'Site: {site_name}\n')
        f.write(f'Status: {status}\n')
        f.write(f'Duration: {duration:.1f}s\n')
        f.write(f'Exit code: {exit_code}\n')
        f.write('=' * 50 + '\n')
        if output:
            f.write(json.dumps(output, indent=2))
    return log_file


def main():
    parser = argparse.ArgumentParser(description='Smoke test runner')
    parser.add_argument('site', nargs='?', help='Site name to test (from sites.yaml)')
    parser.add_argument('--all', action='store_true', help='Test all sites')
    parser.add_argument('--dry-run', action='store_true', help='Show targets without running')
    parser.add_argument('--no-alert', action='store_true', help='Skip email alert on failure')
    parser.add_argument('--post-deploy', action='store_true', help='Post-deploy mode (adds wait)')
    args = parser.parse_args()

    if not args.site and not args.all:
        parser.print_help()
        sys.exit(1)

    config = load_sites()
    sites = config.get('sites', {})

    if args.all:
        targets = list(sites.keys())
    else:
        if args.site not in sites:
            print(f"Site '{args.site}' not found in sites.yaml — skipping.")
            sys.exit(0)  # exit 0: unknown sites skip silently
        targets = [args.site]

    if args.dry_run:
        print("Smoke test targets:")
        for name in targets:
            site = sites[name]
            pages = ', '.join(p['path'] for p in site.get('pages', []))
            print(f"  {name}: {site['url']} [{pages}]")
        sys.exit(0)

    if args.post_deploy:
        os.environ['SMOKE_POST_DEPLOY'] = '1'

    any_failed = False
    for site_name in targets:
        print(f"\n{'='*50}")
        print(f"Testing: {site_name}")
        print(f"{'='*50}")

        try:
            exit_code, duration, results = run_tests(site_name, config)
        except subprocess.TimeoutExpired:
            print("  TIMEOUT after 120s")
            exit_code, duration, results = 1, 120.0, None

        log_file = write_log(site_name, exit_code, duration, results)
        status = 'PASS' if exit_code == 0 else 'FAIL'
        print(f"  Result: {status} ({duration:.1f}s)")
        print(f"  Log: {log_file}")

        if exit_code != 0:
            any_failed = True
            if not args.no_alert:
                try:
                    from alerts import send_failure_alert
                    url = sites[site_name]['url']
                    send_failure_alert(site_name, url, exit_code, duration)
                    print(f"  Alert sent for {site_name}")
                except Exception as e:
                    print(f"  Alert failed: {e}", file=sys.stderr)

    sys.exit(1 if any_failed else 0)


if __name__ == '__main__':
    main()
