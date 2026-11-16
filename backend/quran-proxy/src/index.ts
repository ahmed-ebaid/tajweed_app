import {Buffer} from "node:buffer";
import {
  type AttestationEnv,
  AttestationState,
  attestationStub,
  isKeyId,
  issueAccessToken,
  validateAttestationConfiguration,
  verifyAccessToken,
} from "./attestation";

export interface Env extends AttestationEnv {
  QF_CLIENT_ID: string;
  QF_CLIENT_SECRET: string;
  QF_ENV: "prelive" | "production";
  SIMULATOR_TEST_TOKEN?: string;
  ASR_DIAGNOSTICS?: KVNamespace;
}

interface AccessToken {
  value: string;
  expiresAtMs: number;
}

interface TokenResponse {
  access_token?: unknown;
  expires_in?: unknown;
}

export type Fetcher = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

const CONTENT_PREFIX = "/v2/content/";
const ATTESTATION_PREFIX = "/v1/attest/";
const DIAGNOSTICS_PREFIX = "/v1/asr-diagnostics/";
const DIAGNOSTICS_DO_KEY = `${"D".repeat(43)}=`;
const MAX_DIAGNOSTICS_BODY_LENGTH = 10 * 1024 * 1024;
const TOKEN_SAFETY_WINDOW_MS = 60_000;
const UPSTREAM_TIMEOUT_MS = 15_000;
const MAX_ATTESTATION_REQUEST_LENGTH = 256 * 1024;
const MAX_QUERY_VALUE_LENGTH = 500;
const MAX_REQUEST_ID_LENGTH = 128;
const MAX_UPSTREAM_CONTENT_LENGTH = 10 * 1024 * 1024;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:-]+$/;
const MAX_TELEMETRY_BODY_LENGTH = 1024;

const queryKeys = new Set([
  "audio",
  "bootstrap",
  "chapter_number",
  "cursor",
  "fields",
  "language",
  "mushaf",
  "page",
  "per_page",
  "resources",
  "sync_token",
  "translations",
  "word_fields",
  "words",
]);

const allowedPaths = [
  /^chapters$/,
  /^juzs$/,
  /^quran\/verses\/uthmani_tajweed$/,
  /^recitations\/\d+\/by_chapter\/\d+$/,
  /^resources\/recitations$/,
  /^resources\/snapshots\/(translations|tafsirs|recitations)\/\d+$/,
  /^resources\/sync$/,
  /^resources\/tafsirs$/,
  /^tafsirs\/\d+\/by_ayah\/\d+:\d+$/,
  /^tafsirs\/\d+\/by_chapter\/\d+$/,
  /^verses\/by_chapter\/\d+$/,
  /^verses\/by_key\/\d+:\d+$/,
  /^verses\/by_page\/\d+$/,
];

let cachedToken: AccessToken | undefined;
let pendingToken: Promise<AccessToken> | undefined;

export function resetTokenCacheForTesting(): void {
  cachedToken = undefined;
  pendingToken = undefined;
}

function environmentUrls(env: Env): { authBase: string; apiBase: string } {
  if (env.QF_ENV === "production") {
    return {
      authBase: "https://oauth2.quran.foundation",
      apiBase: "https://apis.quran.foundation",
    };
  }
  return {
    authBase: "https://prelive-oauth2.quran.foundation",
    apiBase: "https://apis-prelive.quran.foundation",
  };
}

function json(
  body: unknown,
  status: number,
  requestId: string,
  extraHeaders: HeadersInit = {},
): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "x-request-id": requestId,
      ...extraHeaders,
    },
  });
}

function requestIdFor(request: Request): string {
  const supplied = request.headers.get("x-request-id");
  if (
    supplied &&
    supplied.length <= MAX_REQUEST_ID_LENGTH &&
    REQUEST_ID_PATTERN.test(supplied)
  ) {
    return supplied;
  }
  return crypto.randomUUID();
}

function validateConfiguration(env: Env): string | undefined {
  if (!env.QF_CLIENT_ID?.trim()) return "QF_CLIENT_ID is not configured";
  if (!env.QF_CLIENT_SECRET?.trim()) {
    return "QF_CLIENT_SECRET is not configured";
  }
  if (env.QF_ENV !== "prelive" && env.QF_ENV !== "production") {
    return "QF_ENV must be prelive or production";
  }
  return undefined;
}

function validateContentRequest(url: URL): string | undefined {
  const encodedPath = url.pathname.slice(CONTENT_PREFIX.length);
  if (!encodedPath || encodedPath.includes("%") || encodedPath.includes("..")) {
    return "Invalid content path";
  }
  if (!allowedPaths.some((pattern) => pattern.test(encodedPath))) {
    return "Unsupported content path";
  }
  for (const [key, value] of url.searchParams) {
    if (!queryKeys.has(key)) return `Unsupported query parameter: ${key}`;
    if (value.length > MAX_QUERY_VALUE_LENGTH) {
      return `Query parameter is too long: ${key}`;
    }
  }
  return undefined;
}

function isDiagnosticsAdminAuthorized(request: Request, env: Env): boolean {
  const configured = env.SIMULATOR_TEST_TOKEN;
  if (!configured || configured.length < 32) return false;
  if (request.headers.get("x-simulator-test-token") === configured) return true;
  const url = new URL(request.url);
  return url.searchParams.get("token") === configured;
}

function isSimulatorTestAuthorized(request: Request, env: Env): boolean {
  if (env.QF_ENV === "production") return false;
  return isDiagnosticsAdminAuthorized(request, env);
}

async function fetchWithTimeout(
  fetcher: Fetcher,
  input: RequestInfo | URL,
  init?: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    return await fetcher(input, {...init, signal: controller.signal});
  } finally {
    clearTimeout(timeout);
  }
}

async function requestAccessToken(
  env: Env,
  fetcher: Fetcher,
): Promise<AccessToken> {
  const {authBase} = environmentUrls(env);
  const authorization = btoa(`${env.QF_CLIENT_ID}:${env.QF_CLIENT_SECRET}`);
  const response = await fetchWithTimeout(
    fetcher,
    `${authBase}/oauth2/token`,
    {
      method: "POST",
      headers: {
        authorization: `Basic ${authorization}`,
        "content-type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials&scope=content",
    },
  );
  if (!response.ok) {
    throw new Error(`OAuth request failed with status ${response.status}`);
  }

  const payload = (await response.json()) as TokenResponse;
  if (
    typeof payload.access_token !== "string" ||
    !payload.access_token ||
    typeof payload.expires_in !== "number" ||
    payload.expires_in <= 0
  ) {
    throw new Error("OAuth response was malformed");
  }

  return {
    value: payload.access_token,
    expiresAtMs: Date.now() + payload.expires_in * 1000,
  };
}

async function getAccessToken(
  env: Env,
  fetcher: Fetcher,
): Promise<AccessToken> {
  if (
    cachedToken &&
    cachedToken.expiresAtMs - TOKEN_SAFETY_WINDOW_MS > Date.now()
  ) {
    return cachedToken;
  }

  pendingToken ??= requestAccessToken(env, fetcher);
  try {
    cachedToken = await pendingToken;
    return cachedToken;
  } finally {
    pendingToken = undefined;
  }
}

function upstreamUrl(requestUrl: URL, env: Env): URL {
  const {apiBase} = environmentUrls(env);
  const path = requestUrl.pathname.slice(CONTENT_PREFIX.length);
  const target = new URL(`/content/api/v4/${path}`, apiBase);
  target.search = requestUrl.search;
  return target;
}

async function callContentApi(
  requestUrl: URL,
  env: Env,
  fetcher: Fetcher,
  retryAfterUnauthorized: boolean,
): Promise<Response> {
  const token = await getAccessToken(env, fetcher);
  const response = await fetchWithTimeout(fetcher, upstreamUrl(requestUrl, env), {
    headers: {
      accept: "application/json",
      "x-auth-token": token.value,
      "x-client-id": env.QF_CLIENT_ID,
    },
  });

  if (response.status === 401 && retryAfterUnauthorized) {
    cachedToken = undefined;
    return callContentApi(requestUrl, env, fetcher, false);
  }
  return response;
}

async function handleAttestationRequest(
  request: Request,
  url: URL,
  env: Env,
  requestId: string,
): Promise<Response> {
  if (request.method !== "POST") {
    return json({error: "Method not allowed"}, 405, requestId, {
      allow: "POST",
    });
  }
  const operation = url.pathname.slice(ATTESTATION_PREFIX.length);
  if (
    !["challenge", "register", "token", "play-integrity"].includes(operation)
  ) {
    return json({error: "Not found"}, 404, requestId);
  }

  const contentLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(contentLength) &&
    contentLength > MAX_ATTESTATION_REQUEST_LENGTH
  ) {
    return json({error: "Request body is too large"}, 413, requestId);
  }

  let rawBody: string;
  let body: Record<string, unknown>;
  try {
    rawBody = await request.text();
    if (rawBody.length > MAX_ATTESTATION_REQUEST_LENGTH) {
      return json({error: "Request body is too large"}, 413, requestId);
    }
    const parsed: unknown = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json({error: "Invalid request"}, 400, requestId);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({error: "Invalid request"}, 400, requestId);
  }

  const keyId = body.key_id;
  if (!isKeyId(keyId)) {
    return json({error: "Invalid request"}, 400, requestId);
  }

  const internal = await attestationStub(env, keyId).fetch(
    new Request(`https://attestation.internal/${operation}`, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: rawBody,
    }),
  );
  const internalBody: unknown = await internal.json();
  if (!internal.ok) {
    return json(internalBody, internal.status, requestId);
  }

  if (operation === "token" || operation === "play-integrity") {
    const access = await issueAccessToken(keyId, env);
    return json(
      {
        access_token: access.token,
        token_type: "Bearer",
        expires_in: access.expiresIn,
      },
      200,
      requestId,
    );
  }
  return json(internalBody, internal.status, requestId);
}

async function handleAttestationFailureTelemetry(
  request: Request,
  requestId: string,
): Promise<Response> {
  if (request.method !== "POST") {
    return json({error: "Method not allowed"}, 405, requestId, {
      allow: "POST",
    });
  }
  const contentLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(contentLength) &&
    contentLength > MAX_TELEMETRY_BODY_LENGTH
  ) {
    return json({error: "Request body is too large"}, 413, requestId);
  }

  let body: unknown;
  try {
    const text = await request.text();
    if (text.length > MAX_TELEMETRY_BODY_LENGTH) {
      return json({error: "Request body is too large"}, 413, requestId);
    }
    body = JSON.parse(text);
  } catch {
    return json({error: "Invalid JSON body"}, 400, requestId);
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({error: "Invalid telemetry event"}, 400, requestId);
  }

  const event = (body as Record<string, unknown>).event;
  const platform = (body as Record<string, unknown>).platform;
  const appVersion = (body as Record<string, unknown>).app_version;
  if (
    (event !== "attestation_failed" &&
      event !== "missing_play_integrity_project_number") ||
    (platform !== "android" && platform !== "ios" && platform !== "other") ||
    typeof appVersion !== "string" ||
    !/^\d+\.\d+\.\d+$/.test(appVersion)
  ) {
    return json({error: "Invalid telemetry event"}, 400, requestId);
  }

  console.warn(`[ATTESTATION_FAIL_CLOSED] ${JSON.stringify({
    requestId,
    event,
    platform,
    appVersion,
  })}`);
  return json({status: "accepted"}, 202, requestId);
}

async function handleDiagnosticsRequest(
  request: Request,
  url: URL,
  env: Env,
  requestId: string,
): Promise<Response> {
  const configurationError = validateAttestationConfiguration(env);
  if (configurationError) {
    console.error(`[${requestId}] ${configurationError}`);
    return json({error: "Service unavailable"}, 503, requestId);
  }
  const operation = url.pathname.slice(DIAGNOSTICS_PREFIX.length);
  if (!["upload", "list", "get", "view", "wav"].includes(operation)) {
    return json({error: "Not found"}, 404, requestId);
  }
  const authorized =
    isDiagnosticsAdminAuthorized(request, env) ||
    await verifyAccessToken(request.headers.get("authorization"), env);
  if (operation !== "upload" && !authorized) {
    return json({error: "Unauthorized"}, 401, requestId);
  }
  if (operation === "view" && request.method === "GET") {
    const token = url.searchParams.get("token") ?? "";
    const internal = await attestationStub(env, DIAGNOSTICS_DO_KEY).fetch(
      new Request("https://attestation.internal/diagnostics-list", {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({key_id: DIAGNOSTICS_DO_KEY}),
      }),
    );
    const data = (await internal.json()) as {
      items?: Array<{
        id: string;
        verseKey: string;
        appVersion: string;
        snapshotCount: number;
        createdAt: number;
      }>;
    };
    const items = data.items ?? [];
    const rows = items
      .map((item) => {
        const ts = new Date(item.createdAt).toISOString().replace("T", " ").slice(0, 19);
        const detailUrl = `/v1/asr-diagnostics/get?id=${encodeURIComponent(item.id)}&token=${encodeURIComponent(token)}`;
        const wavLinks = Array.from({length: item.snapshotCount}, (_, i) =>
          `<a href="/v1/asr-diagnostics/wav?id=${encodeURIComponent(item.id)}&slot=${i}&token=${encodeURIComponent(token)}" style="margin-right:8px">🔊 snapshot-${i}.wav</a>`
        ).join(" ");
        return `<tr>
          <td><code>${item.id}</code></td>
          <td><b>${item.verseKey}</b></td>
          <td>${item.appVersion}</td>
          <td>${item.snapshotCount}</td>
          <td>${ts} UTC</td>
          <td><a href="${detailUrl}" target="_blank">JSON / Logs</a> ${wavLinks}</td>
        </tr>`;
      })
      .join("\n");
    const html = `<!doctype html><html><head><meta charset="utf-8"><title>Tajweed ASR Cloud Recordings</title>
      <style>body{font-family:system-ui,sans-serif;margin:2rem;background:#0f172a;color:#f8fafc}
      table{border-collapse:collapse;width:100%;margin-top:1rem}th,td{border:1px solid #334155;padding:10px;text-align:left}
      th{background:#1e293b}a{color:#38bdf8}</style></head>
      <body><h2>Tajweed ASR Cloud Recordings (${items.length})</h2>
      <table><thead><tr><th>ID</th><th>Verse</th><th>App</th><th>Snapshots</th><th>Uploaded</th><th>Files</th></tr></thead>
      <tbody>${rows}</tbody></table></body></html>`;
    return new Response(html, {
      status: 200,
      headers: {"content-type": "text/html; charset=utf-8", "cache-control": "no-store"},
    });
  }
  if (operation === "wav" && request.method === "GET") {
    const id = url.searchParams.get("id") ?? "";
    const slot = Number(url.searchParams.get("slot") ?? "0");
    const internal = await attestationStub(env, DIAGNOSTICS_DO_KEY).fetch(
      new Request("https://attestation.internal/diagnostics-get", {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({key_id: DIAGNOSTICS_DO_KEY, id}),
      }),
    );
    if (!internal.ok) return json({error: "Not found"}, 404, requestId);
    const bundle = (await internal.json()) as {
      snapshots?: Array<{slot: number; wav_base64?: string}>;
    };
    const match = (bundle.snapshots ?? []).find((s) => s.slot === slot);
    if (!match?.wav_base64) return json({error: "WAV not found"}, 404, requestId);
    const bytes = Buffer.from(match.wav_base64, "base64");
    return new Response(bytes, {
      status: 200,
      headers: {
        "content-type": "audio/wav",
        "content-disposition": `inline; filename="${id}-snapshot-${slot}.wav"`,
      },
    });
  }
  if (
    request.method === "GET" &&
    (operation === "list" || operation === "get")
  ) {
    const targetOp =
      operation === "list" ? "diagnostics-list" : "diagnostics-get";
    const id = url.searchParams.get("id") ?? undefined;
    const internal = await attestationStub(env, DIAGNOSTICS_DO_KEY).fetch(
      new Request(`https://attestation.internal/${targetOp}`, {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({key_id: DIAGNOSTICS_DO_KEY, id}),
      }),
    );
    const internalBody: unknown = await internal.json();
    return json(internalBody, internal.status, requestId);
  }
  if (request.method !== "POST") {
    return json({error: "Method not allowed"}, 405, requestId, {
      allow: "POST",
    });
  }

  const contentLength = Number(request.headers.get("content-length"));
  if (
    Number.isFinite(contentLength) &&
    contentLength > MAX_DIAGNOSTICS_BODY_LENGTH
  ) {
    return json({error: "Request body is too large"}, 413, requestId);
  }

  let rawBody: string;
  let body: Record<string, unknown>;
  try {
    rawBody = await request.text();
    if (rawBody.length > MAX_DIAGNOSTICS_BODY_LENGTH) {
      return json({error: "Request body is too large"}, 413, requestId);
    }
    const parsed: unknown = rawBody ? JSON.parse(rawBody) : {};
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json({error: "Invalid request"}, 400, requestId);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({error: "Invalid request"}, 400, requestId);
  }
  if (
    operation === "upload" &&
    !authorized &&
    (typeof body.verse_key !== "string" ||
      !/^\d{1,3}:\d{1,3}$/.test(body.verse_key) ||
      typeof body.app_version !== "string" ||
      body.app_version.length === 0)
  ) {
    return json({error: "Unauthorized"}, 401, requestId);
  }

  const targetOp =
    operation === "upload"
      ? "diagnostics-save"
      : operation === "list"
      ? "diagnostics-list"
      : "diagnostics-get";

  const internal = await attestationStub(env, DIAGNOSTICS_DO_KEY).fetch(
    new Request(`https://attestation.internal/${targetOp}`, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({...body, key_id: DIAGNOSTICS_DO_KEY}),
    }),
  );
  const internalBody: unknown = await internal.json();
  if (operation === "upload" && internal.ok && env.ASR_DIAGNOSTICS) {
    const savedId =
      internalBody &&
      typeof internalBody === "object" &&
      typeof (internalBody as Record<string, unknown>).id === "string"
        ? ((internalBody as Record<string, unknown>).id as string)
        : typeof body.session_id === "string"
        ? body.session_id
        : requestId;
    const verseSlug =
      typeof body.verse_key === "string"
        ? body.verse_key.replaceAll(":", "_")
        : "unknown";
    const prefix = `${new Date().toISOString().slice(0, 10)}_${verseSlug}_${savedId}`;
    const ttl = {expirationTtl: 14 * 24 * 60 * 60};
    try {
      if (
        typeof body.diagnostics_jsonl === "string" &&
        body.diagnostics_jsonl.length > 0
      ) {
        await env.ASR_DIAGNOSTICS.put(
          `${prefix}/quran-asr-diagnostics.jsonl`,
          body.diagnostics_jsonl,
          ttl,
        );
      }
      if (Array.isArray(body.snapshots)) {
        for (const rawSnap of body.snapshots) {
          if (!rawSnap || typeof rawSnap !== "object") continue;
          const snap = rawSnap as Record<string, unknown>;
          const slot = typeof snap.slot === "number" ? snap.slot : 0;
          if (typeof snap.json === "string" && snap.json.length > 0) {
            await env.ASR_DIAGNOSTICS.put(
              `${prefix}/snapshot-${slot}.json`,
              snap.json,
              ttl,
            );
          }
          if (
            typeof snap.wav_base64 === "string" &&
            snap.wav_base64.length > 0
          ) {
            await env.ASR_DIAGNOSTICS.put(
              `${prefix}/snapshot-${slot}.wav`,
              Buffer.from(snap.wav_base64, "base64"),
              ttl,
            );
          }
        }
      }
    } catch (error) {
      console.warn(`[${requestId}] KV mirror warning: ${String(error)}`);
    }
  }
  return json(internalBody, internal.status, requestId);
}

export async function handleRequest(
  request: Request,
  env: Env,
  fetcher: Fetcher = fetch,
): Promise<Response> {
  const requestId = requestIdFor(request);
  const url = new URL(request.url);

  if (url.pathname === "/v1/telemetry/attestation-failure") {
    return handleAttestationFailureTelemetry(request, requestId);
  }
  if (url.pathname === "/health") {
    if (request.method !== "GET") {
      return json({error: "Method not allowed"}, 405, requestId, {
        allow: "GET",
      });
    }
    return json({status: "ok", environment: env.QF_ENV}, 200, requestId);
  }
  if (url.pathname === "/oauth/callback") {
    if (request.method !== "GET") {
      return json({error: "Method not allowed"}, 405, requestId, {
        allow: "GET",
      });
    }
    return json(
      {
        status: "reserved",
        message: "User OAuth is not enabled for this application.",
      },
      200,
      requestId,
    );
  }
  if (url.pathname.startsWith(ATTESTATION_PREFIX)) {
    const configurationError = validateAttestationConfiguration(env);
    if (configurationError) {
      console.error(`[${requestId}] ${configurationError}`);
      return json({error: "Service unavailable"}, 503, requestId);
    }
    return handleAttestationRequest(request, url, env, requestId);
  }
  if (url.pathname.startsWith(DIAGNOSTICS_PREFIX)) {
    return handleDiagnosticsRequest(request, url, env, requestId);
  }
  if (!url.pathname.startsWith(CONTENT_PREFIX)) {
    return json({error: "Not found"}, 404, requestId);
  }
  if (request.method !== "GET") {
    return json({error: "Method not allowed"}, 405, requestId, {
      allow: "GET",
    });
  }

  const configurationError =
    validateConfiguration(env) ?? validateAttestationConfiguration(env);
  if (configurationError) {
    console.error(`[${requestId}] ${configurationError}`);
    return json({error: "Service unavailable"}, 503, requestId);
  }
  if (
    !isSimulatorTestAuthorized(request, env) &&
    !await verifyAccessToken(request.headers.get("authorization"), env)
  ) {
    return json({error: "Unauthorized"}, 401, requestId);
  }

  const validationError = validateContentRequest(url);
  if (validationError) {
    return json({error: validationError}, 400, requestId);
  }

  try {
    const upstream = await callContentApi(url, env, fetcher, true);
    if (!upstream.ok) {
      await upstream.body?.cancel();
      const status = upstream.status === 401 ? 502 : upstream.status;
      return json({error: "Upstream request failed"}, status, requestId);
    }
    const contentLength = Number(upstream.headers.get("content-length"));
    if (
      Number.isFinite(contentLength) &&
      contentLength > MAX_UPSTREAM_CONTENT_LENGTH
    ) {
      await upstream.body?.cancel();
      return json({error: "Upstream response is too large"}, 502, requestId);
    }
    const headers = new Headers();
    headers.set("content-type", upstream.headers.get("content-type") ??
      "application/json");
    headers.set("x-request-id", requestId);
    headers.set("cache-control", "private, no-store");
    headers.set("cdn-cache-control", "no-store");
    headers.set("cloudflare-cdn-cache-control", "no-store");
    return new Response(upstream.body, {status: upstream.status, headers});
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error(`[${requestId}] Quran Foundation request failed: ${message}`);
    return json({error: "Upstream service unavailable"}, 502, requestId);
  }
}

export {AttestationState};

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return handleRequest(request, env);
  },
} satisfies ExportedHandler<Env>;
