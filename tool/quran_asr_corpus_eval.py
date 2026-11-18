"""Resumable, local-only ASR replay of public Quran.com reciter audio."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import wave

from quran_asr_eval import SAMPLE_RATE, reference_metrics, transcribe_native

API = "https://api.quran.com/api/v4"


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    temporary.replace(path)


def download(url, path):
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Tajweed-ASR-evaluation/1"})
            with urllib.request.urlopen(request, timeout=60) as response:
                content = response.read()
            if not content:
                raise ValueError(f"Empty download: {url}")
            temporary = path.with_suffix(".download")
            temporary.write_bytes(content)
            temporary.replace(path)
            return
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt == 2:
                raise
            print(f"Retrying {url}: {error}", file=sys.stderr, flush=True)
            time.sleep(2 ** (attempt + 1))


def cached_json(url, path):
    download(url, path)
    return json.loads(path.read_text())


def snapshot_ranges(frames, step_seconds):
    """Approximate the app's 8s previews and final bounded 30s snapshot."""
    for end in range(SAMPLE_RATE * step_seconds, frames, SAMPLE_RATE * step_seconds):
        yield max(0, end - SAMPLE_RATE * 8), end, False
    yield max(0, frames - SAMPLE_RATE * 30), frames, True


def audio_url(value):
    url = urllib.parse.urljoin("https://verses.quran.com/", value)
    if urllib.parse.urlparse(url).scheme != "https":
        raise ValueError(f"Non-HTTPS audio URL: {url}")
    return url


def replay(path, cli, model, step_seconds, work):
    wav = work / "decoded.wav"
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(path), str(wav)],
        capture_output=True, text=True, check=True, timeout=120,
    )
    with wave.open(str(wav), "rb") as audio:
        if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) != (1, 2, SAMPLE_RATE):
            raise ValueError("Converter did not produce mono PCM16 at 16 kHz")
        frames = audio.getnframes()
        pcm = audio.readframes(frames)
    if not frames or len(pcm) != frames * 2:
        raise ValueError("Converted audio is empty or truncated")
    snapshots = []
    window = work / "snapshot.wav"
    for start, end, final in snapshot_ranges(frames, step_seconds):
        with wave.open(str(window), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(SAMPLE_RATE)
            audio.writeframes(pcm[start * 2:end * 2])
        snapshot = {
            "start_seconds": start / SAMPLE_RATE,
            "end_seconds": end / SAMPLE_RATE,
            "final": final,
        }
        try:
            report = transcribe_native(window, cli, model, 1)
            snapshot.update(
                transcript=report["transcript"],
                elapsed_seconds_including_model_load=report["elapsed_seconds_including_model_load"],
            )
        except UnicodeDecodeError as error:
            snapshot.update(
                transcript=None,
                decoder_error="invalid_utf8",
                raw_decoder_stdout_hex=error.object.hex(),
            )
            print(f"Invalid decoder UTF-8 at {path}, {start / SAMPLE_RATE}-{end / SAMPLE_RATE}s",
                  file=sys.stderr, flush=True)
        snapshots.append(snapshot)
    wav.unlink()
    window.unlink()
    return frames / SAMPLE_RATE, snapshots


def run(args):
    output = args.output_dir.resolve()
    cache = output / "cache"
    reference = cached_json(f"{API}/quran/verses/imlaei", cache / "references.json")
    verses = reference["verses"]
    keys = [verse["verse_key"] for verse in verses]
    if len(verses) != 6236 or len(set(keys)) != 6236:
        raise ValueError("Expected 6,236 unique Quran references")
    if args.verse_keys:
        unknown = set(args.verse_keys) - set(keys)
        if unknown:
            raise ValueError(f"Unknown verse keys: {sorted(unknown)}")
        verses = [verse for verse in verses if verse["verse_key"] in args.verse_keys]
    reciters = cached_json(f"{API}/resources/recitations?language=en", cache / "reciters.json")["recitations"]
    selected = [reciter for reciter in reciters if reciter["id"] in args.reciters]
    if {reciter["id"] for reciter in selected} != set(args.reciters):
        raise ValueError("Unknown reciter ID")
    config = {
        "model_sha256": hashlib.sha256(args.native_model.read_bytes()).hexdigest(),
        "cli_sha256": hashlib.sha256(args.native_cli.read_bytes()).hexdigest(),
        "preview_step_seconds": args.preview_step_seconds,
        "reciters": selected,
        "verse_keys": [verse["verse_key"] for verse in verses],
        "backend": "whisper.cpp CPU, greedy, no reference prompt or context carryover",
        "notice": (
            "Evaluation, not training. Public studio recordings are not microphone trials "
            "or independent human transcripts, and training-set overlap is unknown. "
            "Expected-text edit rates are not WER. "
            "Previews sample 8s windows at the configured hop, not device inference cadence. "
            "Long ayahs end with a 30s tail; do not score that tail against the whole ayah "
            "without replaying prior snapshots through Hifz."
        ),
    }
    manifest = output / "manifest.json"
    if manifest.exists():
        previous = json.loads(manifest.read_text())
        if any(previous.get(key) != value for key, value in config.items() if key != "notice"):
            raise ValueError("Run configuration changed; choose another output directory")
    save_json(manifest, config)
    total = len(verses) * len(selected)
    completed = 0
    errors = 0
    decoder_errors = 0
    indexes = {}
    index_lock = threading.Lock()

    def evaluate(pair):
        verse, reciter = pair
        key = verse["verse_key"]
        surah, ayah = map(int, key.split(":"))
        reciter_id = reciter["id"]
        result_path = output / "results" / str(reciter_id) / f"{surah:03}-{ayah:03}.json"
        if result_path.exists():
            saved = json.loads(result_path.read_text())
            if saved["status"] in ("ok", "decoder_error"):
                return saved, result_path
        row = {
            "reciter_id": reciter_id, "reciter_name": reciter["reciter_name"],
            "verse_key": key, "expected_text": verse["text_imlaei"],
        }
        work = output / "work" / f"{reciter_id}-{surah}-{ayah}"
        try:
            work.mkdir(parents=True, exist_ok=True)
            with index_lock:
                index_key = (reciter_id, surah)
                if index_key not in indexes:
                    data = cached_json(
                        f"{API}/recitations/{reciter_id}/by_chapter/{surah}?per_page=300",
                        cache / f"audio-{reciter_id}-{surah}.json",
                    )
                    expected_keys = {value for value in keys if value.startswith(f"{surah}:")}
                    actual_keys = {item["verse_key"] for item in data["audio_files"]}
                    if data["pagination"]["next_page"] is not None or actual_keys != expected_keys:
                        raise ValueError(f"Incomplete audio index for reciter {reciter_id}, surah {surah}")
                    indexes[index_key] = {item["verse_key"]: audio_url(item["url"]) for item in data["audio_files"]}
                url = indexes[index_key][key]
            mp3 = cache / str(reciter_id) / f"{surah:03}-{ayah:03}.mp3"
            download(url, mp3)
            duration, snapshots = replay(
                mp3, args.native_cli, args.native_model, args.preview_step_seconds, work,
            )
            work.rmdir()
            row.update(
                status="decoder_error" if any("decoder_error" in item for item in snapshots) else "ok",
                audio_url=url,
                audio_sha256=hashlib.sha256(mp3.read_bytes()).hexdigest(),
                duration_seconds=duration, snapshots=snapshots,
            )
            if duration <= 30 and snapshots[-1]["transcript"] is not None:
                row["final_target_metrics"] = reference_metrics(
                    verse["text_imlaei"], snapshots[-1]["transcript"], "expected",
                )
        except (OSError, ValueError, KeyError, wave.Error, subprocess.SubprocessError) as error:
            row.update(status="error", error=str(error))
            if isinstance(error, subprocess.CalledProcessError):
                row["decoder_or_converter_stderr"] = error.stderr
            print(f"ERROR {reciter_id} {key}: {error}", file=sys.stderr, flush=True)
        save_json(result_path, row)
        return row, result_path

    print(f"Starting/resuming {total} reciter/ayah pairs with {args.workers} workers", flush=True)
    pairs = ((verse, reciter) for verse in verses for reciter in selected)
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        for row, result_path in executor.map(evaluate, pairs):
            if row["status"] in ("ok", "decoder_error"):
                completed += 1
                decoder_errors += row["status"] == "decoder_error"
            else:
                errors += 1
            save_json(output / "progress.json", {
                "total": total, "completed": completed, "errors": errors,
                "decoder_error_recordings": decoder_errors,
                "remaining": total - completed - errors, "latest": str(result_path),
            })
            print(
                f"{completed + errors}/{total} {row['reciter_id']} {row['verse_key']} {row['status']}",
                flush=True,
            )
    save_json(output / "progress.json", {
        "total": total, "completed": completed, "errors": errors,
        "decoder_error_recordings": decoder_errors,
        "remaining": 0, "finished": True,
    })
    return 1 if errors or decoder_errors else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-cli", type=Path, required=True)
    parser.add_argument("--native-model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reciters", type=int, nargs="+", default=[6, 7, 9])
    parser.add_argument("--verse-keys", nargs="+", help="Omit to evaluate all 6,236 ayahs")
    parser.add_argument("--preview-step-seconds", type=int, default=4, choices=range(1, 9))
    parser.add_argument("--workers", type=int, choices=(1, 2), default=1,
                        help="Parallel reciter/ayah jobs, four CPU threads each")
    args = parser.parse_args()
    if not shutil.which("afconvert"):
        parser.error("This corpus tool requires macOS afconvert for public MP3 decoding")
    if not args.native_cli.is_file() or not args.native_model.is_file():
        parser.error("Supply existing native CLI and model files")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    with (args.output_dir / ".lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return run(args)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            parser.exit(1, f"Corpus evaluation failed: {error}\n")


if __name__ == "__main__":
    sys.exit(main())
