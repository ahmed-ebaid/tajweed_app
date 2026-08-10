import {describe, expect, it} from "vitest";
import {
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
