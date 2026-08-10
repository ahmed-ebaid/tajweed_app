# Quran Foundation Compliance Implementation Plan

## Overview

Move all Quran Foundation Content API access behind a secure Cloudflare Worker,
add compliant offline synchronization, and remove unresolved Mushaf-image
distribution paths. The first-year target is up to 1,000 monthly active users.

## Current State Analysis

- The Flutter client calls the legacy Quran.com v4 API directly from
  `lib/core/services/quran_api_service.dart`.
- The app caches Quran content and Tafseer, but a completed cache is not
  revalidated every seven days.
- Connectivity restoration does not trigger an immediate validation attempt.
- The removed `images.zip` release asset is still referenced by
  `lib/core/services/mushaf_assets_service.dart`.
- In-app attribution and the privacy policy still describe the old API and
  Mushaf archive.
- Quran Foundation production access has not yet been requested.

## Desired End State

- Quran Foundation credentials and OAuth exchanges exist only in a deployed
  backend.
- Flutter calls an app-owned HTTPS API and contains no Quran Foundation secret.
- OAuth tokens are cached until shortly before expiry; an upstream `401`
  invalidates the token and is retried exactly once.
- Only required read-only Content API paths and query parameters are proxied.
- Translation, Tafseer, and recitation synchronization uses Content Sync.
- Other cached Quran Foundation resources are revalidated at least every seven
  days when online and promptly after connectivity returns.
- Failed validation retains the last valid cache, records the failure, and
  retries with bounded backoff.
- Updates, deletions, invalidations, and replacement snapshots are applied
  atomically.
- Cached content is not exposed as a raw dataset or separate download.
- Mushaf page downloads remain disabled until written King Fahd Complex
  permission is received.

## Key Discoveries

- Direct API base URL:
  `lib/core/services/quran_api_service.dart:7`.
- Current Content API call surface:
  `lib/core/services/quran_api_service.dart:27-245`.
- Offline sync exits permanently after initial completion:
  `lib/core/services/quran_offline_sync_service.dart:210-231`.
- Removed Mushaf archive is still referenced:
  `lib/core/services/mushaf_assets_service.dart:21-23`.
- Privacy disclosures still name direct API/CDN access:
  `docs/privacy-policy.html:26-27`.
- In-app attribution still claims distribution through GitHub Releases:
  `lib/features/settings/settings_screen.dart:1777`.

## Hosting Comparison

| Area | Cloudflare Workers | Azure Functions Flex Consumption |
| --- | --- | --- |
| Expected cost at 1,000 MAU | Likely $0/month | Likely $0/month |
| Free allowance | 100,000 requests/day | 250,000 executions/month and 100,000 GB-s |
| Paid baseline | $5/month Workers Paid | Usage-based |
| Secret storage | Worker Secrets | App Settings or Key Vault |
| Scheduled work | Cron Triggers | Timer Triggers |
| Global proxy latency | Excellent | Good |
| Operational complexity | Lower | Moderate |
| Selected platform | **Yes** | Fallback option |

The Microsoft FTE $150 monthly Azure credit is Dev/Test-only and must not be
used for this production service.

## What We Are Not Doing

- We will not embed credentials or shared secrets in Flutter.
- We will not restore or replace the 604 Mushaf images without written
  authorization.
- We will not proxy unrelated third-party services solely to make them appear
  first-party.
- We will not add user accounts unless later required for abuse prevention.
- We will not block access to a last valid offline cache solely because an
  update check temporarily failed.

## Phase 1: Secure Cloudflare Worker

### Changes

- Add `backend/quran-proxy` as a TypeScript Cloudflare Worker.
- Store `QF_CLIENT_ID` and `QF_CLIENT_SECRET` as Worker Secrets.
- Support prelive and production Quran Foundation environments.
- Implement OAuth client-credentials exchange and in-isolate token caching.
- Add a read-only, allowlisted `/v1/content/*` proxy.
- Validate path parameters and query parameters.
- Retry once after an upstream `401`.
- Return sanitized errors and request correlation IDs.
- Add unit tests for auth, allowlisting, token reuse, and retry behavior.

### Success Criteria

- No secret exists in source control or responses.
- Unsupported methods, paths, and query keys are rejected.
- Concurrent requests share one token request per isolate.
- A cached token is reused until its safety window.
- An upstream `401` causes exactly one new token request and one retry.
- Worker tests, type-checking, and dry-run deployment pass.

**Implementation Note:** Deploy to prelive and manually verify before Phase 2.

## Phase 2: Flutter Proxy Migration

### Changes

- Make the proxy base URL build-time configurable.
- Replace direct Content API calls with the Worker while preserving response
  shapes expected by `AyahMapper`.
- Inject one API client instead of constructing `QuranApiService` throughout
  the app.
- Keep approved CDN audio delivery direct only if Quran Foundation confirms
  that the returned URLs may be consumed by mobile clients.

### Success Criteria

- Network inspection shows no mobile request to Quran Foundation Content API
  hosts or OAuth hosts.
- Existing reader, search, Tafseer, recitation, and offline tests pass.
- Backend outage falls back to cached content with a visible retry state.

**Implementation Note:** Pause for prelive end-to-end verification.

## Phase 3: Content Sync and Seven-Day Validation

### Changes

- Integrate Content Sync for translations, Tafseer, and recitations.
- Track last successful validation separately from last download.
- Validate on startup when due and immediately after connectivity returns.
- Apply snapshots and invalidations atomically.
- Revalidate unsupported resources through regular endpoints.
- Add bounded exponential backoff with jitter.

### Success Criteria

- A cache at seven days triggers validation when online.
- Connectivity restoration triggers a prompt check.
- Failed checks retain the last valid cache and record the error.
- Deletions and replacement snapshots remove or replace stale content.
- Concurrent checks coalesce into one operation.

**Implementation Note:** Pause for airplane-mode and reconnect testing.

## Phase 4: Mushaf and Legal Surfaces

### Changes

- Disable the broken Mushaf archive download and provide ayah-view fallback.
- Remove claims that the app distributes the removed archive.
- Update Privacy Policy, Terms of Use, and attribution for the backend proxy,
  Quran Foundation, Content Sync, offline retention, and third-party audio.
- Add any resource-specific wording supplied with production approval.

### Success Criteria

- No UI or code attempts to download `images.zip`.
- No public raw Quran Foundation dataset is exposed.
- Policy and attribution links are reachable and match app behavior.
- Mushaf images cannot be restored without an explicit release gate.

## Phase 5: Production Deployment and Release Gate

### Changes

- Submit the Quran Foundation API Access Request.
- Create Cloudflare environments and secrets.
- Deploy and smoke-test prelive, then production.
- Configure observability, alerts, request limits, and budget notifications.
- Perform App Store build verification.

### Success Criteria

- Production credentials exist only in Cloudflare Secrets.
- Health and representative Content API requests succeed.
- Logs contain no access tokens, secrets, or Quran content payloads.
- Compliance tests and release checklist pass.

## Testing Strategy

### Unit Tests

- Allowed and rejected path/query combinations.
- OAuth success, malformed response, timeout, and retry.
- Token expiry safety window and concurrent token acquisition.
- Error sanitization and correlation IDs.
- Seven-day due calculations and clock boundaries.
- Connectivity restoration and retry coalescing.
- Snapshot replacement, deletion, and rollback.

### Integration Tests

- Worker against Quran Foundation prelive.
- Flutter against a local Worker with fixture upstream.
- Offline cache migration from the current schema.
- Backend outage with valid cached content.

### Manual Tests

1. Fresh install online, then complete offline download.
2. Use the app in airplane mode.
3. Advance validation metadata beyond seven days.
4. Restore connectivity and verify immediate validation.
5. Simulate upstream failure and verify cached content remains available.
6. Simulate deletion and replacement snapshot.
7. Confirm no Content API or OAuth traffic originates from the device.

## Performance and Cost

- At 1,000 MAU, both compared platforms should remain within free grants under
  normal reading behavior.
- Cache safe, non-user-specific metadata at the edge where Quran Foundation
  terms and response headers permit it.
- Do not cache OAuth responses outside Worker memory.
- Set explicit upstream timeouts and response-size limits.

## Migration Notes

- Existing on-device content remains readable during migration.
- Add new sync metadata without deleting the current valid cache.
- Roll back the mobile proxy base URL only in prelive; production releases must
  not return to direct credentialed Content API access.

## References

- Quran Foundation OAuth quickstart:
  https://api-docs.quran.foundation/docs/quickstart/
- Quran Foundation access request:
  https://api-docs.quran.foundation/request-access/
- Cloudflare Workers pricing:
  https://developers.cloudflare.com/workers/platform/pricing/
- Cloudflare Workers limits:
  https://developers.cloudflare.com/workers/platform/limits/
- Azure Functions pricing:
  https://azure.microsoft.com/pricing/details/functions/

