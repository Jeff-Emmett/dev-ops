#!/bin/bash
# Scan all CF zones for DNS records with TTL > 300. (Run on Netcup; sourced /opt/secrets/cloudflare/.env)
# Outputs JSONL: {zone_id, zone_name, record_id, name, type, ttl, proxied}
# No mutations. Read-only.

set -eu

source /opt/secrets/cloudflare/.env

OUT="/tmp/cf-ttl-scan.jsonl"
> "$OUT"

ZONES=$(jq -r '.[].id + "\t" + .[].name' /tmp/cf-zones-page*.json 2>/dev/null || \
        jq -s '.[].result[]' /tmp/cf-zones-page*.json | jq -r '.id + "\t" + .name')

# Better approach — pull zones direct
mapfile -t ZONE_LINES < <(jq -s '[.[].result[]] | .[] | "\(.id)\t\(.name)"' /tmp/cf-zones-page*.json -r)

TOTAL=0
for line in "${ZONE_LINES[@]}"; do
    zone_id="${line%%	*}"
    zone_name="${line#*	}"
    records=$(curl -s "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?per_page=500" \
        -H "Authorization: Bearer $CLOUDFLARE_INFRA_TOKEN")
    count=$(echo "$records" | jq '[.result[] | select(.ttl > 300 and .ttl != 1)] | length')
    if [ "$count" -gt 0 ]; then
        TOTAL=$((TOTAL + count))
        echo "$records" | jq -c --arg zid "$zone_id" --arg zname "$zone_name" \
            '.result[] | select(.ttl > 300 and .ttl != 1) | {zone_id: $zid, zone_name: $zname, record_id: .id, name: .name, type: .type, ttl: .ttl, proxied: .proxied}' >> "$OUT"
        echo "  $zone_name: $count records with TTL > 300" >&2
    fi
done

echo ""
echo "TOTAL records to drop: $TOTAL"
echo "Output: $OUT"
