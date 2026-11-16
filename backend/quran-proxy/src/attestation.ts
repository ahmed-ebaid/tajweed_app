import {Buffer} from "node:buffer";
import {verifyAssertion, verifyAttestation} from "node-app-attest";

export type AttestationPurpose = "register" | "assert" | "integrity";

export interface AttestationEnv {
  APPLE_BUNDLE_ID: string;
  APPLE_TEAM_ID: string;
  ATT_TOKEN_SECRET: string;
  ATTESTATION_STATE: DurableObjectNamespace;
  QF_ENV: "prelive" | "production";
  // Android/Play Integrity. Optional: when unset the Play Integrity endpoints
  // report 503 and the iOS App Attest flow is unaffected.
  ANDROID_PACKAGE_NAME?: string;
  ANDROID_CERT_SHA256?: string;
  PLAY_INTEGRITY_SA_EMAIL?: string;
  PLAY_INTEGRITY_SA_PRIVATE_KEY?: string;
}

interface PlayIntegrityVerdict {
  requestDetails?: {
    requestPackageName?: string;
    nonce?: string;
    timestampMillis?: string;
  };
  appIntegrity?: {
    appRecognitionVerdict?: string;
    packageName?: string;
    certificateSha256Digest?: string[];
  };
  deviceIntegrity?: {
    deviceRecognitionVerdict?: string[];
  };
}

interface ChallengeState {
  value: string;
  purpose: AttestationPurpose;
  expiresAtMs: number;
}

interface CredentialState {
  keyId: string;
  publicKey: string;
  environment: "development" | "production";
  signCount: number;
}

interface AccessTokenPayload {
  iss: "tajweed-quran-proxy";
  aud: "quran-content";
  sub: string;
  env: "prelive" | "production";
  iat: number;
  exp: number;
}

const CHALLENGE_KEY = "challenge";
const CREDENTIAL_KEY = "credential";
const CHALLENGE_TTL_MS = 5 * 60 * 1000;
const ACCESS_TOKEN_TTL_SECONDS = 10 * 60;
const KEY_ID_PATTERN = /^[A-Za-z0-9+/]{43}=$/;
const MAX_ATTESTATION_LENGTH = 128 * 1024;
const MAX_ASSERTION_LENGTH = 16 * 1024;
const MAX_INTEGRITY_TOKEN_LENGTH = 64 * 1024;
const MAX_INTEGRITY_CLOCK_SKEW_MS = 60 * 1000;
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const PLAY_INTEGRITY_SCOPE = "https://www.googleapis.com/auth/playintegrity";

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  return Buffer.from(bytes)
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

function decodeBase64Url(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/u.test(value)) {
    throw new Error("Invalid base64url value");
  }
  const standard = value.replaceAll("-", "+").replaceAll("_", "/");
  return new Uint8Array(Buffer.from(standard, "base64"));
}

export function isKeyId(value: unknown): value is string {
  return typeof value === "string" && KEY_ID_PATTERN.test(value);
}

function isBase64Payload(value: unknown, maxLength: number): value is string {
  return typeof value === "string" &&
    value.length > 0 &&
    value.length <= maxLength &&
    /^[A-Za-z0-9+/]+={0,2}$/u.test(value);
}

function internalJson(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {"cache-control": "no-store"},
  });
}

async function readObject(
  request: Request,
  maxLength = MAX_ATTESTATION_LENGTH,
): Promise<Record<string, unknown>> {
  const contentLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength > maxLength) {
    throw new Error("Request body is too large");
  }
  const value: unknown = await request.json();
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Request body must be an object");
  }
  return value as Record<string, unknown>;
}

const MAX_INTERNAL_DIAGNOSTICS_LENGTH = 8 * 1024 * 1024;

export class AttestationState {
  private readonly ctx: DurableObjectState;
  private readonly env: AttestationEnv;

  constructor(ctx: DurableObjectState, env: AttestationEnv) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request: Request): Promise<Response> {
    if (request.method !== "POST") {
      return internalJson({error: "Method not allowed"}, 405);
    }

    try {
      const url = new URL(request.url);
      const isDiag = url.pathname.startsWith("/diagnostics-");
      const body = await readObject(
        request,
        isDiag ? MAX_INTERNAL_DIAGNOSTICS_LENGTH : MAX_ATTESTATION_LENGTH,
      );
      // These are awaited rather than returned directly: returning a promise
      // from inside `try` hands the rejection to the caller instead of the
      // `catch` below, so a rejected handler escaped as an unhandled rejection
      // and the runtime turned it into a 500.
      if (url.pathname === "/challenge") {
        return await this.issueChallenge(body);
      }
      if (url.pathname === "/register") {
        return await this.register(body);
      }
      if (url.pathname === "/token") {
        return await this.verifyForToken(body);
      }
      if (url.pathname === "/play-integrity") {
        return await this.verifyPlayIntegrity(body);
      }
      if (url.pathname === "/diagnostics-save") {
        return await this.saveDiagnostics(body);
      }
      if (url.pathname === "/diagnostics-list") {
        return await this.listDiagnostics();
      }
      if (url.pathname === "/diagnostics-get") {
        return await this.getDiagnostics(body);
      }
      return internalJson({error: "Not found"}, 404);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Invalid request";
      console.warn(`App Attest request rejected: ${message}`);
      return internalJson({error: "Unauthorized"}, 401);
    }
  }

  private async issueChallenge(
    body: Record<string, unknown>,
  ): Promise<Response> {
    const keyId = body.key_id;
    const purpose = body.purpose;
    if (
      !isKeyId(keyId) ||
      (purpose !== "register" && purpose !== "assert" && purpose !== "integrity")
    ) {
      return internalJson({error: "Invalid request"}, 400);
    }
    if (purpose === "integrity" && !this.playIntegrityConfigured()) {
      return internalJson({error: "Play Integrity is not configured"}, 503);
    }

    // Play Integrity has no long-lived registered credential, so the
    // register/assert credential checks below intentionally do not apply.
    const credential = await this.ctx.storage.get<CredentialState>(CREDENTIAL_KEY);
    if (purpose === "register" && credential) {
      return internalJson({error: "Key is already registered"}, 409);
    }
    if (purpose === "assert" && (!credential || credential.keyId !== keyId)) {
      return internalJson({error: "Key is not registered"}, 401);
    }

    const challenge = base64Url(crypto.getRandomValues(new Uint8Array(32)));
    await this.ctx.storage.put<ChallengeState>(CHALLENGE_KEY, {
      value: challenge,
      purpose,
      expiresAtMs: Date.now() + CHALLENGE_TTL_MS,
    });
    return internalJson({
      challenge,
      expires_in: Math.floor(CHALLENGE_TTL_MS / 1000),
    });
  }

  private async consumeChallenge(
    value: unknown,
    purpose: AttestationPurpose,
  ): Promise<string> {
    const stored = await this.ctx.storage.get<ChallengeState>(CHALLENGE_KEY);
    await this.ctx.storage.delete(CHALLENGE_KEY);
    if (
      typeof value !== "string" ||
      !stored ||
      stored.value !== value ||
      stored.purpose !== purpose ||
      stored.expiresAtMs <= Date.now()
    ) {
      throw new Error("Challenge is invalid or expired");
    }
    return value;
  }

  private async register(body: Record<string, unknown>): Promise<Response> {
    const keyId = body.key_id;
    if (!isKeyId(keyId) ||
        !isBase64Payload(body.attestation, MAX_ATTESTATION_LENGTH)) {
      return internalJson({error: "Invalid request"}, 400);
    }
    if (await this.ctx.storage.get(CREDENTIAL_KEY)) {
      return internalJson({error: "Key is already registered"}, 409);
    }

    const challenge = await this.consumeChallenge(body.challenge, "register");
    const result = verifyAttestation({
      attestation: Buffer.from(body.attestation, "base64"),
      challenge,
      keyId,
      bundleIdentifier: this.env.APPLE_BUNDLE_ID,
      teamIdentifier: this.env.APPLE_TEAM_ID,
      allowDevelopmentEnvironment: true,
    });
    if (
      result.environment !== "development" &&
      result.environment !== "production"
    ) {
      throw new Error("Attestation environment is invalid");
    }

    const credential: CredentialState = {
      keyId,
      publicKey: String(result.publicKey),
      environment: result.environment,
      signCount: 0,
    };
    await this.ctx.storage.put(CREDENTIAL_KEY, credential);
    return internalJson({status: "registered"}, 201);
  }

  private async verifyForToken(
    body: Record<string, unknown>,
  ): Promise<Response> {
    const keyId = body.key_id;
    if (!isKeyId(keyId) ||
        !isBase64Payload(body.assertion, MAX_ASSERTION_LENGTH)) {
      return internalJson({error: "Invalid request"}, 400);
    }

    const challenge = await this.consumeChallenge(body.challenge, "assert");
    const credential =
      await this.ctx.storage.get<CredentialState>(CREDENTIAL_KEY);
    if (!credential || credential.keyId !== keyId) {
      throw new Error("Credential was not found");
    }
    if (
      credential.environment !== "development" &&
      credential.environment !== "production"
    ) {
      throw new Error("Credential environment is invalid");
    }

    const result = verifyAssertion({
      assertion: Buffer.from(body.assertion, "base64"),
      payload: challenge,
      publicKey: credential.publicKey,
      bundleIdentifier: this.env.APPLE_BUNDLE_ID,
      teamIdentifier: this.env.APPLE_TEAM_ID,
      signCount: credential.signCount,
    });
    if (!Number.isSafeInteger(result.signCount) ||
        result.signCount <= credential.signCount) {
      throw new Error("Assertion counter is invalid");
    }

    credential.signCount = result.signCount;
    await this.ctx.storage.put(CREDENTIAL_KEY, credential);
    return internalJson({status: "verified", key_id: keyId});
  }

  private playIntegrityConfigured(): boolean {
    return Boolean(
      this.env.ANDROID_PACKAGE_NAME &&
        this.env.ANDROID_CERT_SHA256 &&
        this.env.PLAY_INTEGRITY_SA_EMAIL &&
        this.env.PLAY_INTEGRITY_SA_PRIVATE_KEY,
    );
  }

  private async verifyPlayIntegrity(
    body: Record<string, unknown>,
  ): Promise<Response> {
    const keyId = body.key_id;
    const integrityToken = body.integrity_token;
    if (
      !isKeyId(keyId) ||
      typeof integrityToken !== "string" ||
      integrityToken.length === 0 ||
      integrityToken.length > MAX_INTEGRITY_TOKEN_LENGTH
    ) {
      return internalJson({error: "Invalid request"}, 400);
    }
    if (!this.playIntegrityConfigured()) {
      return internalJson({error: "Play Integrity is not configured"}, 503);
    }

    // Consume first: a challenge is single-use even if verification fails, so a
    // rejected token cannot be replayed against the same challenge.
    const challenge = await this.consumeChallenge(body.challenge, "integrity");
    const verdict = await decodeIntegrityToken(integrityToken, this.env);
    assertPlayIntegrityVerdict(verdict, challenge, this.env);
    return internalJson({status: "verified", key_id: keyId});
  }

  private async saveDiagnostics(
    body: Record<string, unknown>,
  ): Promise<Response> {
    const id = typeof body.id === "string" && /^[A-Za-z0-9._:-]{1,64}$/u.test(body.id)
      ? body.id
      : crypto.randomUUID();
    const verseKey = typeof body.verse_key === "string" && /^\d{1,3}:\d{1,3}$/u.test(body.verse_key)
      ? body.verse_key
      : "unknown";
    const appVersion = typeof body.app_version === "string" && body.app_version.length <= 32
      ? body.app_version
      : "unknown";
    const createdAt = Date.now();
    const diagnosticsJsonl = typeof body.diagnostics_jsonl === "string" && body.diagnostics_jsonl.length <= 128 * 1024
      ? body.diagnostics_jsonl
      : "";
    const snapshotsRaw = Array.isArray(body.snapshots) ? body.snapshots.slice(0, 6) : [];
    const snapshotMeta: Array<{slot: number; json: string; wavChunks: number; wavBytes: number}> = [];

    for (let i = 0; i < snapshotsRaw.length; i++) {
      const item = snapshotsRaw[i];
      if (!item || typeof item !== "object") continue;
      const rec = item as Record<string, unknown>;
      const slot = typeof rec.slot === "number" && Number.isInteger(rec.slot) && rec.slot >= 0 && rec.slot < 6
        ? rec.slot
        : i;
      const metaJson = typeof rec.json === "string" && rec.json.length <= 64 * 1024
        ? rec.json
        : "{}";
      const wavBase64 = typeof rec.wav_base64 === "string" && rec.wav_base64.length <= 1400000
        ? rec.wav_base64
        : "";
      const wavBytes = wavBase64 ? Buffer.from(wavBase64, "base64") : Buffer.alloc(0);
      const chunkSize = 64 * 1024;
      let chunks = 0;
      for (let offset = 0; offset < wavBytes.length; offset += chunkSize) {
        const slice = wavBytes.subarray(offset, offset + chunkSize);
        await this.ctx.storage.put(`diag_wav:${id}:${slot}:${chunks}`, new Uint8Array(slice));
        chunks++;
      }
      snapshotMeta.push({
        slot,
        json: metaJson,
        wavChunks: chunks,
        wavBytes: wavBytes.length,
      });
    }

    const index = (await this.ctx.storage.get<string[]>("diag_index")) ?? [];
    index.unshift(id);
    while (index.length > 25) {
      const evicted = index.pop();
      if (evicted) {
        await this.deleteDiagnosticEntry(evicted);
      }
    }
    await this.ctx.storage.put(`diag_meta:${id}`, {
      id,
      verseKey,
      appVersion,
      createdAt,
      diagnosticsJsonl,
      snapshots: snapshotMeta,
    });
    await this.ctx.storage.put("diag_index", index);
    return internalJson({status: "saved", id, snapshots: snapshotMeta.length}, 201);
  }

  private async deleteDiagnosticEntry(id: string): Promise<void> {
    const meta = await this.ctx.storage.get<{snapshots?: Array<{slot: number; wavChunks: number}>}>(`diag_meta:${id}`);
    if (meta?.snapshots) {
      for (const snap of meta.snapshots) {
        for (let c = 0; c < snap.wavChunks; c++) {
          await this.ctx.storage.delete(`diag_wav:${id}:${snap.slot}:${c}`);
        }
      }
    }
    await this.ctx.storage.delete(`diag_meta:${id}`);
  }

  private async listDiagnostics(): Promise<Response> {
    const index = (await this.ctx.storage.get<string[]>("diag_index")) ?? [];
    const items: Array<Record<string, unknown>> = [];
    for (const id of index) {
      const meta = await this.ctx.storage.get<Record<string, unknown>>(`diag_meta:${id}`);
      if (meta) {
        items.push({
          id: meta.id,
          verseKey: meta.verseKey,
          appVersion: meta.appVersion,
          createdAt: meta.createdAt,
          snapshotCount: Array.isArray(meta.snapshots) ? meta.snapshots.length : 0,
        });
      }
    }
    return internalJson({items});
  }

  private async getDiagnostics(body: Record<string, unknown>): Promise<Response> {
    const id = typeof body.id === "string" ? body.id : "";
    const meta = await this.ctx.storage.get<{
      id: string;
      verseKey: string;
      appVersion: string;
      createdAt: number;
      diagnosticsJsonl: string;
      snapshots: Array<{slot: number; json: string; wavChunks: number; wavBytes: number}>;
    }>(`diag_meta:${id}`);
    if (!meta) {
      return internalJson({error: "Not found"}, 404);
    }
    const snapshots: Array<Record<string, unknown>> = [];
    for (const snap of meta.snapshots) {
      const parts: Buffer[] = [];
      for (let c = 0; c < snap.wavChunks; c++) {
        const chunk = await this.ctx.storage.get<Uint8Array>(`diag_wav:${id}:${snap.slot}:${c}`);
        if (chunk) parts.push(Buffer.from(chunk));
      }
      snapshots.push({
        slot: snap.slot,
        json: snap.json,
        wav_base64: Buffer.concat(parts).toString("base64"),
      });
    }
    return internalJson({
      id: meta.id,
      verseKey: meta.verseKey,
      appVersion: meta.appVersion,
      createdAt: meta.createdAt,
      diagnostics_jsonl: meta.diagnosticsJsonl,
      snapshots,
    });
  }
}

/// Drops trailing base64 padding so padded and unpadded encodings of the same
/// value compare equal. Returns undefined unchanged so a missing nonce can
/// never match a real challenge.
function stripBase64Padding(value: string | undefined): string | undefined {
  return value?.replace(/=+$/, "");
}

/// Asserts every property the Android client claims. Any mismatch throws, and
/// the caller converts that into a 401.
export function assertPlayIntegrityVerdict(
  verdict: PlayIntegrityVerdict,
  challenge: string,
  env: AttestationEnv,
): void {
  const packageName = env.ANDROID_PACKAGE_NAME;
  const request = verdict.requestDetails;

  // Binds this token to the challenge we just issued (replay defence).
  // Play Integrity echoes the nonce back with base64 padding restored, while
  // the challenges we mint are unpadded base64url, so compare canonical forms.
  if (stripBase64Padding(request?.nonce) !== stripBase64Padding(challenge)) {
    throw new Error("Integrity nonce does not match the challenge");
  }
  if (request?.requestPackageName !== packageName) {
    throw new Error("Integrity request package name is invalid");
  }

  const age = Date.now() - Number(request?.timestampMillis ?? Number.NaN);
  if (
    !Number.isFinite(age) ||
    age < -MAX_INTEGRITY_CLOCK_SKEW_MS ||
    age > CHALLENGE_TTL_MS
  ) {
    throw new Error("Integrity token is expired");
  }

  // App identity. Google only populates packageName/certificateSha256Digest
  // when Play recognized the build ("set iff app_recognition_verdict !=
  // UNEVALUATED"), so a sideloaded build reports UNEVALUATED and carries no app
  // identity at all. Production still demands the full identity, because it also
  // requires PLAY_RECOGNIZED below and therefore always has these fields. Outside
  // production we fall back to requestDetails.requestPackageName, which Play
  // Services fills in from the real calling package and is verified above.
  const app = verdict.appIntegrity;
  const identityAvailable = app?.appRecognitionVerdict !== "UNEVALUATED";
  if (env.QF_ENV === "production" || identityAvailable) {
    if (app?.packageName !== packageName) {
      throw new Error("Integrity package name is invalid");
    }
    if (
      !(app?.certificateSha256Digest ?? []).includes(env.ANDROID_CERT_SHA256!)
    ) {
      throw new Error("Integrity signing certificate is not trusted");
    }
  }

  // Genuine, untampered device. Production demands a Play-certified device;
  // prelive also accepts MEETS_BASIC_INTEGRITY so a device that fails only the
  // stricter hardware-backed check can still be used for testing. Note this is
  // not enough to let an emulator through: emulators return an empty verdict by
  // design and cannot pass either label, so the last mile of this flow can only
  // be exercised on physical hardware. The verdict is echoed into the error
  // because an empty list and a rejected list are otherwise indistinguishable
  // from the client.
  const device = verdict.deviceIntegrity?.deviceRecognitionVerdict ?? [];
  const accepted =
    env.QF_ENV === "production"
      ? ["MEETS_DEVICE_INTEGRITY"]
      : ["MEETS_DEVICE_INTEGRITY", "MEETS_BASIC_INTEGRITY"];
  if (!accepted.some((label) => device.includes(label))) {
    throw new Error(
      `Device does not meet integrity requirements (verdict: ${
        device.join(",") || "none"
      })`,
    );
  }

  // Mirrors the App Attest development/production split: prelive tolerates
  // sideloaded builds so they can be tested, production does not.
  if (
    env.QF_ENV === "production" &&
    app?.appRecognitionVerdict !== "PLAY_RECOGNIZED"
  ) {
    throw new Error("App is not recognized by Google Play");
  }
}

async function decodeIntegrityToken(
  integrityToken: string,
  env: AttestationEnv,
): Promise<PlayIntegrityVerdict> {
  const accessToken = await googleAccessToken(env);
  const packageName = encodeURIComponent(env.ANDROID_PACKAGE_NAME!);
  const response = await fetch(
    `https://playintegrity.googleapis.com/v1/${packageName}:decodeIntegrityToken`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({integrity_token: integrityToken}),
    },
  );
  if (!response.ok) {
    throw new Error(`Play Integrity decode failed with ${response.status}`);
  }
  const payload = (await response.json()) as {
    tokenPayloadExternal?: PlayIntegrityVerdict;
  };
  if (!payload.tokenPayloadExternal) {
    throw new Error("Play Integrity response is malformed");
  }
  return payload.tokenPayloadExternal;
}

/// Exchanges a service-account JWT for a Google access token. Workers have no
/// google-auth library, so the RS256 assertion is built with WebCrypto.
async function googleAccessToken(env: AttestationEnv): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({alg: "RS256", typ: "JWT"}));
  const claims = base64Url(
    JSON.stringify({
      iss: env.PLAY_INTEGRITY_SA_EMAIL,
      scope: PLAY_INTEGRITY_SCOPE,
      aud: GOOGLE_TOKEN_URL,
      iat: nowSeconds,
      exp: nowSeconds + 300,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    await serviceAccountKey(env.PLAY_INTEGRITY_SA_PRIVATE_KEY!),
    new TextEncoder().encode(signingInput),
  );

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: {"content-type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${signingInput}.${base64Url(new Uint8Array(signature))}`,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google token exchange failed with ${response.status}`);
  }
  const payload = (await response.json()) as {access_token?: string};
  if (!payload.access_token) {
    throw new Error("Google token response is malformed");
  }
  return payload.access_token;
}

async function serviceAccountKey(pem: string): Promise<CryptoKey> {
  // Secrets are commonly stored with literal \n escapes.
  const normalized = pem.replaceAll("\\n", "\n");
  const match =
    /-----BEGIN PRIVATE KEY-----([\s\S]+?)-----END PRIVATE KEY-----/u.exec(
      normalized,
    );
  if (!match) {
    throw new Error("Service account key is not a PKCS#8 PEM");
  }
  const der = Buffer.from(match[1].replace(/\s+/gu, ""), "base64");
  return crypto.subtle.importKey(
    "pkcs8",
    new Uint8Array(der),
    {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"},
    false,
    ["sign"],
  );
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    {name: "HMAC", hash: "SHA-256"},
    false,
    ["sign", "verify"],
  );
}

export async function issueAccessToken(
  keyId: string,
  env: AttestationEnv,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<{token: string; expiresIn: number}> {
  const header = base64Url(JSON.stringify({alg: "HS256", typ: "JWT"}));
  const payload: AccessTokenPayload = {
    iss: "tajweed-quran-proxy",
    aud: "quran-content",
    sub: keyId,
    env: env.QF_ENV,
    iat: nowSeconds,
    exp: nowSeconds + ACCESS_TOKEN_TTL_SECONDS,
  };
  const encodedPayload = base64Url(JSON.stringify(payload));
  const signingInput = `${header}.${encodedPayload}`;
  const signature = await crypto.subtle.sign(
    "HMAC",
    await hmacKey(env.ATT_TOKEN_SECRET),
    new TextEncoder().encode(signingInput),
  );
  return {
    token: `${signingInput}.${base64Url(new Uint8Array(signature))}`,
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
  };
}

export async function verifyAccessToken(
  authorization: string | null,
  env: AttestationEnv,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  if (!authorization?.startsWith("Bearer ") ||
      authorization.length > 4096) {
    return false;
  }
  const parts = authorization.slice(7).split(".");
  if (parts.length !== 3) return false;

  try {
    const [header, payload, signature] = parts;
    const signingInput = `${header}.${payload}`;
    const validSignature = await crypto.subtle.verify(
      "HMAC",
      await hmacKey(env.ATT_TOKEN_SECRET),
      decodeBase64Url(signature),
      new TextEncoder().encode(signingInput),
    );
    if (!validSignature) return false;

    const parsedHeader = JSON.parse(
      new TextDecoder().decode(decodeBase64Url(header)),
    ) as Record<string, unknown>;
    const parsedPayload = JSON.parse(
      new TextDecoder().decode(decodeBase64Url(payload)),
    ) as Partial<AccessTokenPayload>;
    return parsedHeader.alg === "HS256" &&
      parsedHeader.typ === "JWT" &&
      parsedPayload.iss === "tajweed-quran-proxy" &&
      parsedPayload.aud === "quran-content" &&
      parsedPayload.env === env.QF_ENV &&
      isKeyId(parsedPayload.sub) &&
      Number.isSafeInteger(parsedPayload.iat) &&
      Number.isSafeInteger(parsedPayload.exp) &&
      (parsedPayload.iat as number) <= nowSeconds + 30 &&
      (parsedPayload.exp as number) > nowSeconds &&
      (parsedPayload.exp as number) - (parsedPayload.iat as number) <=
        ACCESS_TOKEN_TTL_SECONDS;
  } catch {
    return false;
  }
}

export function validateAttestationConfiguration(
  env: Partial<AttestationEnv>,
): string | undefined {
  if (!env.ATTESTATION_STATE) return "ATTESTATION_STATE is not configured";
  if (env.APPLE_TEAM_ID !== "Y6484R42R9") {
    return "APPLE_TEAM_ID is not configured correctly";
  }
  if (env.APPLE_BUNDLE_ID !== "com.ebaidllc.tajweedpractice") {
    return "APPLE_BUNDLE_ID is not configured correctly";
  }
  if (!env.ATT_TOKEN_SECRET || env.ATT_TOKEN_SECRET.length < 32) {
    return "ATT_TOKEN_SECRET must contain at least 32 characters";
  }
  return undefined;
}

export function attestationStub(
  env: AttestationEnv,
  keyId: string,
): DurableObjectStub {
  return env.ATTESTATION_STATE.getByName(keyId);
}
