export interface Env {
  QF_CLIENT_ID: string;
  QF_CLIENT_SECRET: string;
  QF_ENV: "prelive" | "production";
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

const CONTENT_PREFIX = "/v1/content/";
const TOKEN_SAFETY_WINDOW_MS = 60_000;
const UPSTREAM_TIMEOUT_MS = 15_000;
const MAX_QUERY_VALUE_LENGTH = 500;
const MAX_REQUEST_ID_LENGTH = 128;
const MAX_UPSTREAM_CONTENT_LENGTH = 10 * 1024 * 1024;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:-]+$/;

const queryKeys = new Set([
  "audio",
  "bootstrap",
  "chapter_number",
  "cursor",
  "fields",
  "language",
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

export async function handleRequest(
  request: Request,
  env: Env,
  fetcher: Fetcher = fetch,
): Promise<Response> {
  const requestId = requestIdFor(request);
  const url = new URL(request.url);

  if (request.method !== "GET") {
    return json({error: "Method not allowed"}, 405, requestId, {
      allow: "GET",
    });
  }
  if (url.pathname === "/health") {
    return json({status: "ok", environment: env.QF_ENV}, 200, requestId);
  }
  if (url.pathname === "/oauth/callback") {
    return json(
      {
        status: "reserved",
        message: "User OAuth is not enabled for this application.",
      },
      200,
      requestId,
    );
  }
  if (!url.pathname.startsWith(CONTENT_PREFIX)) {
    return json({error: "Not found"}, 404, requestId);
  }

  const configurationError = validateConfiguration(env);
  if (configurationError) {
    console.error(`[${requestId}] ${configurationError}`);
    return json({error: "Service unavailable"}, 503, requestId);
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
    const cacheControl = upstream.headers.get("cache-control");
    if (cacheControl) headers.set("cache-control", cacheControl);
    return new Response(upstream.body, {status: upstream.status, headers});
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error(`[${requestId}] Quran Foundation request failed: ${message}`);
    return json({error: "Upstream service unavailable"}, 502, requestId);
  }
}

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return handleRequest(request, env);
  },
} satisfies ExportedHandler<Env>;
