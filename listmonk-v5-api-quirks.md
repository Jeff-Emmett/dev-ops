# Listmonk v5 API quirks (encountered 2026-05-08)

Self-hosted listmonk v5.1.0 (image: `listmonk/listmonk:v5.1.0`).

These are reproducible quirks worth filing upstream at https://github.com/knadh/listmonk/issues. Captured here as reference until filed.

---

## 1. `POST /api/templates` returns `Invalid length for name.` for valid names

**Auth:** API user with role having full template permissions
(`templates:get_all,templates:manage_all,templates:get,templates:manage`).

**Request:**
```http
POST /api/templates
Authorization: token <user>:<token>
Content-Type: application/json

{
  "name": "Tenant Welcome",
  "type": "tx",
  "subject": "Welcome",
  "body": "<p>Hello</p>"
}
```

**Response:**
```json
{ "message": "Invalid length for name." }
```

`name` is 14 chars — well within the 1–200 char range that the schema allows. Same string inserted directly via SQL works:

```sql
INSERT INTO templates (name, type, subject, body, is_default)
VALUES ('Tenant Welcome', 'tx', 'Welcome', '<p>Hello</p>', false);
```

Hit consistently across five fresh tenant instances. Not an admin-vs-API permission issue (admin user via the JSON-RPC console hits the same error). Suspect a request-body validator ordering bug where `name` is tested against the wrong field's length constraint.

**Workaround:** seed templates with direct SQL.

---

## 2. `POST /api/subscribers` returns `Invalid email.` for valid emails

Same auth/conditions as above.

**Request:**
```json
{
  "email": "person@example.com",
  "name": "Person",
  "status": "enabled",
  "lists": [3]
}
```

**Response:** `{ "message": "Invalid email." }`

Email passes RFC 5321 / RFC 5322 checks. Direct SQL insert works.

**Workaround:** SQL `INSERT INTO subscribers (uuid, email, name, status, attribs)` then `INSERT INTO subscriber_lists`.

---

## 3. `PUT /api/settings` data-loss bug — passwords overwritten with literal mask characters

**Trigger:** read settings via `GET /api/settings`, modify any unrelated field (e.g. `app.site_name`), `PUT` the response back.

**Behavior:** any field whose value comes from a credential (SMTP password, bounces password, etc.) is returned by `GET` as a literal string of `•` (bullet) mask characters. `PUT` does NOT detect-and-skip these — it persists the bullets verbatim, replacing the real password.

**Symptom in production:** SMTP messengers start failing with `535 Authentication failed` because listmonk now sends the literal string `••••••••` as the password. Mailcow (or upstream MTA) may treat this as a brute-force attempt and lock the mailbox.

**Severity:** silent data corruption affecting outbound email. We hit this on the KT instance and had to rotate the `orders@katheryntrenshaw.com` mailbox password via Mailcow then re-paste it into listmonk.

**Workarounds:**
- Always substitute the real password back into the response body before `PUT`.
- Or update only the changed setting via direct SQL: `UPDATE settings SET value = '"new value"'::jsonb WHERE key = 'app.site_name';`
- Long-term fix should be upstream: either return a sentinel that the `PUT` validator skips, or make `PUT` accept partial documents.

---

## 4. New API user not active until container restart

After creating an API user via SQL `INSERT INTO users (... type='api', user_role_id=<super-admin>)`, calls authenticated as that user fail with `535` until the listmonk container is restarted. Suggests an in-memory user/token cache that is not invalidated on user inserts.

**Workaround:** `docker restart <listmonk-container>` after seeding API users via SQL. Restart is fast (<3s) and idempotent.

## 5. Tx-template registry not refreshed after SQL insert

Same shape as #4 but for templates. After `INSERT INTO templates (..., type='tx', ...)`, calling `POST /api/tx` with `template_id=<new id>` returns `template <N> not found` even though `GET /api/templates` lists it correctly and the user role has `templates:get_all`. The /api/tx path uses an in-memory `tplCache` map populated at startup and not invalidated on insert.

**Workaround:** `docker restart <listmonk-container>` after seeding tx templates via SQL.

Reproduced 2026-05-09 on xhiva-listmonk: template id=5 visible in `GET /api/templates` but `POST /api/tx` returned `{"message":"template 5 not found"}`. Restart fixed it; subsequent send returned `{"data":true}` and the email arrived with the expected From header.

---

## Test environment

- Listmonk image: `listmonk/listmonk:v5.1.0`
- Postgres: `postgres:16-alpine`
- 5 separate instances (commons-hub, KT, xhiva, crypto-commons, worldplay), all reproduce #1 and #2.
- #3 reproduced on KT during phase-1 multi-tenant rollout.
- #4 reproduced on every fresh instance during the SQL-seed bootstrap.
