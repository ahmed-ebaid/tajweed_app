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

Never commit `.dev.vars`. Production secrets must be configured with:

```bash
npx wrangler secret put QF_CLIENT_ID
npx wrangler secret put QF_CLIENT_SECRET
```

Use `QF_ENV=prelive` until pre-production verification succeeds. Set
`QF_ENV=production` only in the production Worker environment.

## Routes

- `GET /health`
- `GET /oauth/callback` (reserved placeholder; user OAuth is not enabled)
- `GET /v1/content/<allowlisted Content API path>`

The proxy forwards only the Content API paths and query keys required by the
mobile app. It does not expose a generic upstream URL proxy.

Quran Foundation Search uses a separate API and OAuth scope. It is intentionally
not exposed by this Content API Worker and will be integrated separately.

## Validation

```bash
npm run check
npm test
npm run deploy:dry-run
```
