# Quran Foundation proxy

Cloudflare Worker that keeps Quran Foundation credentials and OAuth token
exchange outside the Flutter application. Apple App Attest protects every
Content API route from clients that are not genuine iOS app installations.

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
npx wrangler secret put ATT_TOKEN_SECRET --env=""
```

Configure the independent production Worker with the production credentials:

```bash
npx wrangler secret put QF_CLIENT_ID --env production
npx wrangler secret put QF_CLIENT_SECRET --env production
npx wrangler secret put ATT_TOKEN_SECRET --env production
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
- `POST /v1/attest/challenge`
- `POST /v1/attest/register`
- `POST /v1/attest/token`
- `GET /v2/content/<allowlisted Content API path>`
- `GET /v2/content/resources/sync`
- `GET /v2/content/resources/snapshots/{translations|tafsirs|recitations}/{id}`

The proxy forwards only the Content API paths and query keys required by the
mobile app. It does not expose a generic upstream URL proxy.
Content Sync and snapshot `Cache-Control: no-store` headers are preserved.

App Attest registration validates Apple's certificate chain, the app/team
identifier, challenge nonce, key identifier, and production/development
environment. Assertions use single-use five-minute challenges and a monotonic
counter stored in a per-key Durable Object. A valid assertion returns a
ten-minute environment-bound bearer token. Content routes fail closed without
that token. Production accepts only production attestations; prelive also
accepts development attestations from physical development devices.

`ATT_TOKEN_SECRET` must be an independent random value of at least 32
characters in each environment. Rotating it immediately invalidates all
outstanding bearer tokens. Do not reuse Quran.Foundation credentials.

App Attest requires a physical iOS 14+ device. Simulator, macOS, Android, and
older app builds cannot call protected Content routes.

Quran Foundation Search uses a separate API and OAuth scope. It is intentionally
not exposed by this Content API Worker and will be integrated separately.

## Validation

```bash
npm run check
npm test
npm run deploy:dry-run
npm run deploy:production:dry-run
```
