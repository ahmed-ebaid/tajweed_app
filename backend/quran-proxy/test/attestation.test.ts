import {describe, expect, it} from "vitest";
import {
  assertPlayIntegrityVerdict,
  AttestationState,
  type AttestationEnv,
  issueAccessToken,
  verifyAccessToken,
} from "../src/attestation";

const keyId = `${"A".repeat(43)}=`;
const namespace = {} as DurableObjectNamespace;
const preliveEnv: AttestationEnv = {
  APPLE_BUNDLE_ID: "com.ebaidllc.tajweedpractice",
  APPLE_TEAM_ID: "Y6484R42R9",
  ATT_TOKEN_SECRET: "prelive-secret-with-at-least-32-characters",
  ATTESTATION_STATE: namespace,
  QF_ENV: "prelive",
};

describe("attestation access tokens", () => {
  it("accepts a valid unexpired token", async () => {
    const issued = await issueAccessToken(keyId, preliveEnv, 1_000);

    expect(
      await verifyAccessToken(
        `Bearer ${issued.token}`,
        preliveEnv,
        1_001,
      ),
    ).toBe(true);
  });

  it("rejects expired, tampered, and missing tokens", async () => {
    const issued = await issueAccessToken(keyId, preliveEnv, 1_000);
    const tampered = `${issued.token.slice(0, -1)}A`;

    expect(
      await verifyAccessToken(
        `Bearer ${issued.token}`,
        preliveEnv,
        1_601,
      ),
    ).toBe(false);
    expect(await verifyAccessToken(`Bearer ${tampered}`, preliveEnv)).toBe(false);
    expect(await verifyAccessToken(null, preliveEnv)).toBe(false);
  });

  it("rejects tokens from another Worker environment", async () => {
    const issued = await issueAccessToken(keyId, preliveEnv, 1_000);
    const productionEnv: AttestationEnv = {
      ...preliveEnv,
      QF_ENV: "production",
    };

    expect(
      await verifyAccessToken(
        `Bearer ${issued.token}`,
        productionEnv,
        1_001,
      ),
    ).toBe(false);
  });
});

describe("attestation error handling", () => {
  const androidEnv: AttestationEnv = {
    ...preliveEnv,
    ANDROID_PACKAGE_NAME: "com.ebaidllc.tajweed_practice",
    ANDROID_CERT_SHA256: "uHVYILQjjRrFxPOzF24JkwcoehlBs0Kpt4y6PTzOjb4",
    PLAY_INTEGRITY_SA_EMAIL: "verifier@example.iam.gserviceaccount.com",
    PLAY_INTEGRITY_SA_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----",
  };

  function stateWithEmptyStorage(env: AttestationEnv): AttestationState {
    const stored = new Map<string, unknown>();
    const ctx = {
      storage: {
        get: async (key: string) => stored.get(key),
        put: async (key: string, value: unknown) => void stored.set(key, value),
        delete: async (key: string) => void stored.delete(key),
      },
    } as unknown as DurableObjectState;
    return new AttestationState(ctx, env);
  }

  function post(path: string, body: unknown): Request {
    return new Request(`https://attestation.internal/${path}`, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify(body),
    });
  }

  // A rejected handler promise must surface as 401, not as an unhandled
  // rejection that the Workers runtime reports as a 500.
  it("rejects an unknown play-integrity challenge with 401", async () => {
    const response = await stateWithEmptyStorage(androidEnv).fetch(
      post("play-integrity", {
        key_id: keyId,
        challenge: "not-the-stored-challenge",
        integrity_token: "bogus",
      }),
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({error: "Unauthorized"});
  });

  it("rejects an unknown assert challenge with 401", async () => {
    const response = await stateWithEmptyStorage(preliveEnv).fetch(
      post("token", {key_id: keyId, challenge: "nope", assertion: "AAAA"}),
    );

    expect(response.status).toBe(401);
  });
});

describe("play integrity device verdict", () => {
  const challenge = "the-challenge";
  const certDigest = "uHVYILQjjRrFxPOzF24JkwcoehlBs0Kpt4y6PTzOjb4";

  function envFor(qfEnv: AttestationEnv["QF_ENV"]): AttestationEnv {
    return {
      ...preliveEnv,
      QF_ENV: qfEnv,
      ANDROID_PACKAGE_NAME: "com.ebaidllc.tajweed_practice",
      ANDROID_CERT_SHA256: certDigest,
    };
  }

  // A verdict that passes every check except the device one, so each test
  // isolates the device label rather than tripping an earlier assertion.
  function verdictWith(deviceLabels: string[]) {
    return {
      requestDetails: {
        nonce: challenge,
        requestPackageName: "com.ebaidllc.tajweed_practice",
        timestampMillis: String(Date.now()),
      },
      appIntegrity: {
        packageName: "com.ebaidllc.tajweed_practice",
        certificateSha256Digest: [certDigest],
        appRecognitionVerdict: "PLAY_RECOGNIZED",
      },
      deviceIntegrity: {deviceRecognitionVerdict: deviceLabels},
    };
  }

  it("accepts MEETS_BASIC_INTEGRITY on prelive so emulators can be tested", () => {
    expect(() =>
      assertPlayIntegrityVerdict(
        verdictWith(["MEETS_BASIC_INTEGRITY"]),
        challenge,
        envFor("prelive"),
      ),
    ).not.toThrow();
  });

  it("rejects MEETS_BASIC_INTEGRITY in production", () => {
    expect(() =>
      assertPlayIntegrityVerdict(
        verdictWith(["MEETS_BASIC_INTEGRITY"]),
        challenge,
        envFor("production"),
      ),
    ).toThrow(/integrity requirements/);
  });

  it("accepts MEETS_DEVICE_INTEGRITY in production", () => {
    expect(() =>
      assertPlayIntegrityVerdict(
        verdictWith(["MEETS_DEVICE_INTEGRITY"]),
        challenge,
        envFor("production"),
      ),
    ).not.toThrow();
  });

  it("rejects an empty verdict on prelive and names it in the error", () => {
    expect(() =>
      assertPlayIntegrityVerdict(verdictWith([]), challenge, envFor("prelive")),
    ).toThrow(/verdict: none/);
  });

  // Play Integrity echoes the nonce back with base64 padding restored, even
  // though the challenges we issue are unpadded base64url.
  it("accepts a nonce that Play returned with base64 padding restored", () => {
    const verdict = verdictWith(["MEETS_DEVICE_INTEGRITY"]);
    verdict.requestDetails.nonce = `${challenge}=`;
    expect(() =>
      assertPlayIntegrityVerdict(verdict, challenge, envFor("production")),
    ).not.toThrow();
  });

  it("still rejects a nonce that differs beyond padding", () => {
    const verdict = verdictWith(["MEETS_DEVICE_INTEGRITY"]);
    verdict.requestDetails.nonce = "someone-elses-challenge=";
    expect(() =>
      assertPlayIntegrityVerdict(verdict, challenge, envFor("production")),
    ).toThrow(/nonce does not match/);
  });

  it("rejects a missing nonce", () => {
    const verdict = verdictWith(["MEETS_DEVICE_INTEGRITY"]);
    verdict.requestDetails.nonce = undefined as unknown as string;
    expect(() =>
      assertPlayIntegrityVerdict(verdict, challenge, envFor("production")),
    ).toThrow(/nonce does not match/);
  });
});

// Google omits packageName/certificateSha256Digest unless Play recognized the
// build, so a sideloaded APK carries no app identity at all.
describe("play integrity app identity", () => {
  const challenge = "challenge-value";
  const certDigest = "cert-digest";

  function envFor(qfEnv: AttestationEnv["QF_ENV"]): AttestationEnv {
    return {
      ...preliveEnv,
      QF_ENV: qfEnv,
      ANDROID_PACKAGE_NAME: "com.ebaidllc.tajweed_practice",
      ANDROID_CERT_SHA256: certDigest,
    };
  }

  // Mirrors what Play actually returns for a sideloaded build: the request
  // details name the real calling package, but appIntegrity is bare.
  function unevaluatedVerdict() {
    return {
      requestDetails: {
        nonce: challenge,
        requestPackageName: "com.ebaidllc.tajweed_practice",
        timestampMillis: String(Date.now()),
      },
      appIntegrity: {appRecognitionVerdict: "UNEVALUATED"},
      deviceIntegrity: {deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"]},
    };
  }

  it("accepts an UNEVALUATED sideload on prelive", () => {
    expect(() =>
      assertPlayIntegrityVerdict(
        unevaluatedVerdict(),
        challenge,
        envFor("prelive"),
      ),
    ).not.toThrow();
  });

  it("still rejects an UNEVALUATED sideload in production", () => {
    expect(() =>
      assertPlayIntegrityVerdict(
        unevaluatedVerdict(),
        challenge,
        envFor("production"),
      ),
    ).toThrow(/package name is invalid/);
  });

  // The relaxation must not become a hole: a token minted for a different app
  // is still rejected, because requestPackageName is checked unconditionally.
  it("rejects an UNEVALUATED verdict from a different package on prelive", () => {
    const verdict = unevaluatedVerdict();
    verdict.requestDetails.requestPackageName = "com.attacker.app";
    expect(() =>
      assertPlayIntegrityVerdict(verdict, challenge, envFor("prelive")),
    ).toThrow(/request package name is invalid/);
  });

  // When Play *does* evaluate the app, the identity checks must still apply
  // outside production too.
  it("enforces the cert digest on prelive once Play recognizes the app", () => {
    const verdict = unevaluatedVerdict();
    verdict.appIntegrity = {
      appRecognitionVerdict: "PLAY_RECOGNIZED",
      packageName: "com.ebaidllc.tajweed_practice",
      certificateSha256Digest: ["some-other-digest"],
    } as never;
    expect(() =>
      assertPlayIntegrityVerdict(verdict, challenge, envFor("prelive")),
    ).toThrow(/certificate is not trusted/);
  });
});
