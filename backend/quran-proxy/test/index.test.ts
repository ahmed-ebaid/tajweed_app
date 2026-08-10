import {afterEach, describe, expect, it, vi} from "vitest";
import {
  type Env,
  type Fetcher,
  handleRequest,
  resetTokenCacheForTesting,
} from "../src/index";

const env: Env = {
  QF_CLIENT_ID: "client-id",
  QF_CLIENT_SECRET: "client-secret",
  QF_ENV: "prelive",
};

function tokenResponse(token = "token-1"): Response {
  return Response.json({access_token: token, expires_in: 3600});
}

afterEach(() => {
  resetTokenCacheForTesting();
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("Quran Foundation proxy", () => {
  it("serves health without credentials", async () => {
    const response = await handleRequest(
      new Request("https://proxy.example/health"),
      {...env, QF_CLIENT_SECRET: ""},
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      status: "ok",
      environment: "prelive",
    });
  });

  it("rejects unsupported methods, paths, and query keys", async () => {
    const post = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters", {method: "POST"}),
      env,
    );
    const path = await handleRequest(
      new Request("https://proxy.example/v1/content/admin/secrets"),
      env,
    );
    const query = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters?redirect=https://x"),
      env,
    );
    const healthPost = await handleRequest(
      new Request("https://proxy.example/health", {method: "POST"}),
      env,
    );

    expect(post.status).toBe(405);
    expect(path.status).toBe(400);
    expect(query.status).toBe(400);
    expect(healthPost.status).toBe(405);
  });

  it("rejects search, encoded paths, and oversized query values", async () => {
    const search = await handleRequest(
      new Request("https://proxy.example/v1/content/search?q=mercy"),
      env,
    );
    const encodedPath = await handleRequest(
      new Request("https://proxy.example/v1/content/verses%2Fby_page%2F1"),
      env,
    );
    const oversizedQuery = await handleRequest(
      new Request(
        `https://proxy.example/v1/content/chapters?language=${"a".repeat(501)}`,
      ),
      env,
    );

    expect(search.status).toBe(400);
    expect(encodedPath.status).toBe(400);
    expect(oversizedQuery.status).toBe(400);
  });

  it("rejects missing configuration without calling upstream", async () => {
    const fetcher = vi.fn<Fetcher>();
    const response = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      {...env, QF_CLIENT_SECRET: ""},
      fetcher,
    );

    expect(response.status).toBe(503);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("obtains and reuses one OAuth token", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(tokenResponse())
      .mockResolvedValueOnce(Response.json({chapters: []}))
      .mockResolvedValueOnce(Response.json({juzs: []}));

    const first = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters?language=en"),
      env,
      fetcher,
    );
    const second = await handleRequest(
      new Request("https://proxy.example/v1/content/juzs"),
      env,
      fetcher,
    );

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(fetcher.mock.calls[0][0].toString()).toContain("/oauth2/token");
    expect(fetcher.mock.calls[1][0].toString()).toContain(
      "/content/api/v4/chapters?language=en",
    );
    expect(
      new Headers(fetcher.mock.calls[1][1]?.headers).get("x-auth-token"),
    ).toBe("token-1");
  });

  it("refreshes once and retries after an upstream 401", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(tokenResponse("expired-token"))
      .mockResolvedValueOnce(new Response(null, {status: 401}))
      .mockResolvedValueOnce(tokenResponse("new-token"))
      .mockResolvedValueOnce(Response.json({chapters: []}));

    const response = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );

    expect(response.status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(4);
    expect(
      new Headers(fetcher.mock.calls[3][1]?.headers).get("x-auth-token"),
    ).toBe("new-token");
  });

  it("does not retry a second upstream 401", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(tokenResponse("expired-token"))
      .mockResolvedValueOnce(new Response(null, {status: 401}))
      .mockResolvedValueOnce(tokenResponse("new-token"))
      .mockResolvedValueOnce(new Response(null, {status: 401}));

    const response = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({error: "Upstream request failed"});
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("coalesces concurrent OAuth token requests", async () => {
    let releaseToken!: (response: Response) => void;
    const pendingToken = new Promise<Response>((resolve) => {
      releaseToken = resolve;
    });
    const fetcher = vi.fn<Fetcher>()
      .mockReturnValueOnce(pendingToken)
      .mockResolvedValueOnce(Response.json({chapters: []}))
      .mockResolvedValueOnce(Response.json({juzs: []}));

    const first = handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );
    const second = handleRequest(
      new Request("https://proxy.example/v1/content/juzs"),
      env,
      fetcher,
    );
    await vi.waitFor(() => expect(fetcher).toHaveBeenCalledTimes(1));
    releaseToken(tokenResponse());

    expect((await first).status).toBe(200);
    expect((await second).status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(3);
  });

  it("refreshes tokens inside the expiry safety window", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(Response.json({
        access_token: "short-token",
        expires_in: 30,
      }))
      .mockResolvedValueOnce(Response.json({chapters: []}))
      .mockResolvedValueOnce(tokenResponse("fresh-token"))
      .mockResolvedValueOnce(Response.json({juzs: []}));

    await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );
    await handleRequest(
      new Request("https://proxy.example/v1/content/juzs"),
      env,
      fetcher,
    );

    expect(fetcher).toHaveBeenCalledTimes(4);
    expect(
      new Headers(fetcher.mock.calls[3][1]?.headers).get("x-auth-token"),
    ).toBe("fresh-token");
  });

  it("returns a sanitized error after an upstream timeout", async () => {
    vi.useFakeTimers();
    const fetcher = vi.fn<Fetcher>((_input, init) =>
      new Promise((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => {
          reject(new DOMException("Request timed out", "AbortError"));
        });
      })
    );

    const responsePromise = handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );
    await vi.advanceTimersByTimeAsync(15_000);
    const response = await responsePromise;

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({
      error: "Upstream service unavailable",
    });
  });

  it("replaces unsafe request IDs", async () => {
    const response = await handleRequest(
      new Request("https://proxy.example/health", {
        headers: {"x-request-id": "unsafe request id"},
      }),
      env,
    );

    expect(response.headers.get("x-request-id")).toMatch(
      /^[0-9a-f]{8}-[0-9a-f-]{27}$/,
    );
  });

  it("does not leak OAuth errors to clients", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(
        Response.json(
          {error: "invalid_client", client_secret: env.QF_CLIENT_SECRET},
          {status: 401},
        ),
      );

    const response = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );
    const body = await response.text();

    expect(response.status).toBe(502);
    expect(body).not.toContain(env.QF_CLIENT_SECRET);
    expect(body).not.toContain("invalid_client");
  });

  it("does not leak Content API error bodies to clients", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(tokenResponse())
      .mockResolvedValueOnce(
        Response.json(
          {error: "internal details", token: "upstream-secret"},
          {status: 500},
        ),
      );

    const response = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );
    const body = await response.text();

    expect(response.status).toBe(500);
    expect(body).toBe(JSON.stringify({error: "Upstream request failed"}));
    expect(body).not.toContain("upstream-secret");
  });

  it("rejects declared upstream responses over ten MiB", async () => {
    const fetcher = vi.fn<Fetcher>()
      .mockResolvedValueOnce(tokenResponse())
      .mockResolvedValueOnce(
        new Response("small fixture", {
          headers: {"content-length": String(10 * 1024 * 1024 + 1)},
        }),
      );

    const response = await handleRequest(
      new Request("https://proxy.example/v1/content/chapters"),
      env,
      fetcher,
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({
      error: "Upstream response is too large",
    });
  });
});
