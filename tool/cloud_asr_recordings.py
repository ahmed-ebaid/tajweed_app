#!/usr/bin/env python3
"""Inspect or pull cloud-stored Quran ASR recordings from Cloudflare Worker."""
import base64
import datetime
import json
import os
import sys
import urllib.request

WORKER_URL = "https://tajweed-quran-proxy-production.ebaidllc.workers.dev"
TOKEN_PATHS = [
    os.environ.get("QURAN_DIAG_TOKEN_FILE", ""),
    "/Users/ahmedebaid/.copilot/session-state/c789e607-eec9-413e-8c79-2a1e67bd0c85/files/simulator-test-token.txt",
    os.path.expanduser(
        "~/.copilot/session-state/2b4b0741-eba5-4ee8-a389-a8dd9ff69595/files/simulator-test-token.txt"
    ),
]


def load_token() -> str:
    env_tok = os.environ.get("SIMULATOR_TEST_TOKEN", "").strip()
    if env_tok:
        return env_tok
    for p in TOKEN_PATHS:
        if p and os.path.exists(p):
            return open(p).read().strip()
    raise RuntimeError(
        "Missing SIMULATOR_TEST_TOKEN env var or simulator-test-token.txt"
    )


def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{WORKER_URL}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "user-agent": "Dart/3.10 (dart:io)",
            "x-simulator-test-token": load_token(),
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_bundle(target_id: str, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    bundle = post("/v1/asr-diagnostics/get", {"id": target_id})
    jsonl_path = os.path.join(out_dir, "quran-asr-diagnostics.jsonl")
    with open(jsonl_path, "w") as f:
        f.write(bundle.get("diagnostics_jsonl", ""))
    for snap in bundle.get("snapshots", []):
        slot = snap["slot"]
        with open(os.path.join(out_dir, f"snapshot-{slot}.json"), "w") as f:
            f.write(snap.get("json", "{}"))
        wav_b64 = snap.get("wav_base64", "")
        if wav_b64:
            with open(os.path.join(out_dir, f"snapshot-{slot}.wav"), "wb") as f:
                f.write(base64.b64decode(wav_b64))
    print(f"Downloaded bundle '{target_id}' -> {out_dir}")


def main() -> None:
    res = post("/v1/asr-diagnostics/list", {})
    items = res.get("items", [])
    print(
        f"Cloud storage ({WORKER_URL}/v1/asr-diagnostics): {len(items)} bundle(s)"
    )
    for item in items:
        ts = datetime.datetime.fromtimestamp(item["createdAt"] / 1000.0).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        print(
            f"  - id={item['id']} | verse={item['verseKey']} | app={item['appVersion']} | snapshots={item['snapshotCount']} | uploaded={ts}"
        )

    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg == "--all":
            base_dir = sys.argv[2] if len(sys.argv) > 2 else "build/cloud-recordings"
            for item in items:
                verse = item.get("verseKey", "unknown").replace(":", "_")
                bid = item["id"]
                download_bundle(bid, os.path.join(base_dir, f"{verse}_{bid[:8]}"))
        else:
            out_dir = sys.argv[2] if len(sys.argv) > 2 else f"build/cloud-recordings/{arg}"
            download_bundle(arg, out_dir)


if __name__ == "__main__":
    main()

