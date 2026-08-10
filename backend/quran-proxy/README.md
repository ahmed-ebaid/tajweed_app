# Quran Foundation proxy

Cloudflare Worker that keeps Quran Foundation credentials and OAuth token
exchange outside the Flutter application.

## Local setup

```bash
npm install
cp .dev.vars.example .dev.vars
# Fill in prelive credentials after Quran Foundation grants access.
npm run dev
```

Never commit `.dev.vars`. Configure prelive secrets on the existing Worker with:

```bash
npx wrangler secret put QF_CLIENT_ID --env=""
npx wrangler secret put QF_CLIENT_SECRET --env=""
```

Configure the independent production Worker with the production credentials:

```bash
npx wrangler secret put QF_CLIENT_ID --env production
npx wrangler secret put QF_CLIENT_SECRET --env production
npm run deploy:production
```

The deployments and credentials remain isolated:

| Environment | Worker | Quran Foundation environment |
| --- | --- | --- |
| Prelive | `tajweed-quran-proxy` | `prelive` |
| Production | `tajweed-quran-proxy-production` | `production` |

## Routes

- `GET /health`
- `GET /oauth/callback` (reserved placeholder; user OAuth is not enabled)
- `GET /v1/content/<allowlisted Content API path>`
- `GET /v1/content/resources/sync`
- `GET /v1/content/resources/snapshots/{translations|tafsirs|recitations}/{id}`

The proxy forwards only the Content API paths and query keys required by the
mobile app. It does not expose a generic upstream URL proxy.
Content Sync and snapshot `Cache-Control: no-store` headers are preserved.

Quran Foundation Search uses a separate API and OAuth scope. It is intentionally
not exposed by this Content API Worker and will be integrated separately.

## Validation

```bash
npm run check
npm test
npm run deploy:dry-run
npm run deploy:production:dry-run
```
