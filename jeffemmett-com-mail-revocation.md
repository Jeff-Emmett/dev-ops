# jeffemmett.com mail revocation — handoff

Started 2026-05-09. Final cleanup scheduled **2026-05-11 (T+48h)** to allow MX cache propagation.

## What was done 2026-05-09

### MX cutover (13 tenant domains: `mx.jeffemmett.com` → `mail.rmail.online`)

| Domain | New MX |
|---|---|
| alltor.net | mail.rmail.online |
| cadcad.org | mail.rmail.online |
| compostcapitalism.xyz | mail.rmail.online |
| jeffemmett.com | mail.rmail.online |
| jefflix.lol | mail.rmail.online |
| mycofi.earth | mail.rmail.online |
| mycopunk.xyz | mail.rmail.online |
| post-appitalism.app | mail.rmail.online |
| psilo-cyber.net | mail.rmail.online |
| rspace.online | mail.rmail.online |
| trippinballs.lol | mail.rmail.online |
| undernet.earth | mail.rmail.online |
| worldplay.art | mail.rmail.online |

All TTLs set to 300s. CF API PATCH succeeded for all 13.

### jeffemmett.com auxiliary changes

- **SPF**: `v=spf1 a mx a:mx.jeffemmett.com -all` → `v=spf1 a:mail.rmail.online -all`
- **autoconfig.jeffemmett.com** CNAME → `mail.rmail.online` (was `mx.jeffemmett.com`)
- **autodiscover.jeffemmett.com** CNAME → `mail.rmail.online` (was `mx.jeffemmett.com`)

### Mailcow Traefik

`/opt/mailcow/docker-compose.override.yml` rule changed to:
```yaml
- "traefik.http.routers.mailcow.rule=Host(`mail.rmail.online`) || Host(`mail.jeffemmett.com`)"
```
Backup: `docker-compose.override.yml.bak.<timestamp>` in same dir.
Webmail/admin UI now reachable at both hostnames. `mail.rmail.online` direct A 159.195.32.209 (not CF-proxied — no Access protection).

## Pre-cutover infra context

- `mail.rmail.online` already had A 159.195.32.209 direct (not proxied).
- `mx.jeffemmett.com` A 159.195.32.209 (same IP). MX cutover keeps mail flowing to the same Postfix.
- PTR for 159.195.32.209 is already `mail.rmail.online`. SMTP banner already says `mail.rmail.online`.
- Mailcow live cert is **self-signed**, CN=`mx.jeffemmett.com`, SAN=`mx.jeffemmett.com,mail.jeffemmett.com`. Hand-placed in `/opt/mailcow/data/assets/ssl/cert.pem` so mailcow ACME skips. All tenant relays already use `tls_skip_verify=true`. Cert reissue is **out of scope** of this revocation; tracking separately if it ever becomes a real LE cert covering `mail.rmail.online`.

## What's pending — scheduled for 2026-05-11+

### 1. Delete jeffemmett.com mail-related DNS records

Wait until 48h after cutover (so cached MX → mx.jeffemmett.com all expired) before deleting:

```bash
source ~/.cloudflare-credentials.env
JZ=45c200f8dc2a01852e41b9bb09eb7359  # jeffemmett.com zone

# Verify nothing is depending on these before delete
for n in mx.jeffemmett.com mail.jeffemmett.com ; do
  echo "=== $n ==="
  REC=$(curl -sf -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$JZ/dns_records?name=$n" | jq -c '.result[]')
  echo "$REC" | jq '{type, name, content, id}'
done

# Delete (uncomment after verification)
# for n in mx.jeffemmett.com mail.jeffemmett.com ; do
#   ID=$(curl -sf -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
#     "https://api.cloudflare.com/client/v4/zones/$JZ/dns_records?name=$n" | jq -r '.result[0].id')
#   curl -sS -X DELETE "https://api.cloudflare.com/client/v4/zones/$JZ/dns_records/$ID" \
#     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq .
# done
```

### 2. Strip `mail.jeffemmett.com` from mailcow Traefik rule

After mail.jeffemmett.com CNAME is gone:

```bash
ssh netcup-full 'cd /opt/mailcow && python3 -c "
import pathlib
p = pathlib.Path(\"docker-compose.override.yml\")
src = p.read_text()
old = \"Host(\`mail.rmail.online\`) || Host(\`mail.jeffemmett.com\`)\"
new = \"Host(\`mail.rmail.online\`)\"
p.write_text(src.replace(old, new))
" && docker compose up -d nginx-mailcow'
```

### 3. Remove `ADDITIONAL_SAN=mx.jeffemmett.com` from mailcow.conf

Cosmetic (ACME is bypassed, the hand-managed cert is what's served), but completes the revocation:

```bash
ssh netcup-full "sed -i '/^ADDITIONAL_SAN=mx.jeffemmett.com/d' /opt/mailcow/mailcow.conf && grep ADDITIONAL_SAN /opt/mailcow/mailcow.conf"
```

## Pending — separate migration project (NOT 48h-bounded)

### `email-relay.jeffemmett.com` — actively used by canvas-website

This is **not** a stale DNS record. It's a CF-tunneled service behind CF Access used by canvas-website (`cryptidAuth.ts` → `sendEmail`, board-permissions worker). References:
- `/opt/apps/canvas-website-dev/tests/worker/board-permissions.test.ts:78` — `EMAIL_RELAY_URL: 'https://email-relay.jeffemmett.com'`
- `/opt/apps/canvas-website-dev/tests/worker/cryptid-auth.test.ts:61` — same
- `/opt/apps/canvas-website-dev/backlog/tasks/task-064` — original migration ticket from Resend → mailcow, mentions "Deployed at email-relay.jeffemmett.com"

To migrate:
1. Stand up `email-relay.rmail.online` CNAME → cloudflared tunnel
2. Add it to the cloudflared tunnel ingress
3. Apply same CF Access policy (or move `mycopunks.cloudflareaccess.com` Application from `email-relay.jeffemmett.com` to `email-relay.rmail.online`)
4. Update canvas-website env `EMAIL_RELAY_URL=https://email-relay.rmail.online` (prod + dev workers, plus tests)
5. Verify cryptid-auth + board-permissions flows
6. Then delete `email-relay.jeffemmett.com` CNAME

Best done as part of a canvas-website-touching session, not bundled into the mail revocation.

## Other notes

- `cosmolocal.world` is in mailcow domain list but routes via Cloudflare Email Routing (`route1.mx.cloudflare.net` etc) — NOT actually receiving on mailcow. Out of scope.
- `news.commons-hub.at`, `news.crypto-commons.org`, `news.worldplay.art` — outbound-only listmonk subdomains, no MX intentionally.
- `rnetwork.online`, `rwork.online` — no MX configured, outbound-only.
