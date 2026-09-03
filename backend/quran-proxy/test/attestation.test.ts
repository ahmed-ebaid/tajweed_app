import {describe, expect, it} from "vitest";
import {
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
