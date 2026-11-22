"""Index locally cached reciter audio as unverified, verse-labeled references."""

import argparse
import hashlib
import json
import shutil
from pathlib import Path


def build_catalog(sources, output, pilot_surah):
    output.mkdir(parents=True, exist_ok=True)
    entries = []
    seen = set()
    reciter_splits = {}
    pilot_reciters = {}
    pilot_verses = set()
    pilot_files = []
    for split, source in sources:
        source = source.resolve()
        manifest = json.loads((source / "manifest.json").read_text())
        reciters = {r["id"]: r for r in manifest["reciters"]}
        for reciter in reciters:
            if reciter in reciter_splits and reciter_splits[reciter] != split:
                raise ValueError(f"Reciter {reciter} appears in multiple splits")
            reciter_splits[reciter] = split
        verses = set(manifest["verse_keys"])
        found = set()
        for path in sorted((source / "results").glob("*/*.json")):
            row = json.loads(path.read_text())
            reciter = row["reciter_id"]
            verse = row["verse_key"]
            pair = (reciter, verse)
            if reciter not in reciters or verse not in verses or pair in seen:
                raise ValueError(f"Unexpected or duplicate recording: {path}")
            surah, ayah = map(int, verse.split(":"))
            if path.parent.name != str(reciter) or path.stem != f"{surah:03d}-{ayah:03d}":
                raise ValueError(f"Recording path does not match its verse: {path}")
            seen.add(pair)
            found.add(pair)
            audio = source / "cache" / str(reciter) / f"{path.stem}.mp3"
            if not audio.is_file():
                raise ValueError(f"Missing audio: {audio}")
            with audio.open("rb") as audio_file:
                audio_sha256 = hashlib.file_digest(audio_file, "sha256").hexdigest()
            if audio_sha256 != row["audio_sha256"]:
                raise ValueError(f"Audio hash does not match: {audio}")
            entries.append({
                "reciter_id": reciter,
                "reciter_name": row["reciter_name"],
                "verse_key": verse,
                "expected_text": row["expected_text"],
                "label": "reference_recitation_unverified",
                "review_status": "not_reviewed",
                "split": split,
                "audio_path": str(audio),
                "audio_url": row["audio_url"],
                "audio_sha256": audio_sha256,
                "result_path": str(path),
                "decoder_status": row["status"],
                "model_sha256": manifest["model_sha256"],
                "preview_step_seconds": manifest["preview_step_seconds"],
            })
            if verse.split(":")[0] == str(pilot_surah):
                destination = output / "pilot" / "results" / str(reciter) / path.name
                pilot_files.append((path, destination))
                pilot_reciters[reciter] = reciters[reciter]
                pilot_verses.add(verse)
        expected = {(reciter, verse) for reciter in reciters for verse in verses}
        if found != expected:
            raise ValueError(f"Incomplete source {source}: {len(found)} of {len(expected)} pairs")
    if not pilot_verses:
        raise ValueError(f"No recordings found for pilot surah {pilot_surah}")
    expected_pilot = {(reciter, verse) for reciter in pilot_reciters for verse in pilot_verses}
    if not expected_pilot.issubset(seen):
        raise ValueError("Pilot is missing reciter/verse pairs")
    for path, destination in pilot_files:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
    catalog = output / "reference-catalog.jsonl"
    with catalog.open("w", encoding="utf-8") as file:
        for entry in entries:
            file.write(json.dumps(entry, ensure_ascii=False) + "\n")
    pilot = {
        "reciters": list(pilot_reciters.values()),
        "verse_keys": sorted(pilot_verses, key=lambda x: tuple(map(int, x.split(":")))),
        "notice": "Reference recitations are not independently reviewed correctness labels.",
    }
    (output / "pilot" / "manifest.json").write_text(
        json.dumps(pilot, ensure_ascii=False, indent=2) + "\n"
    )
    return len(entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", action="append", required=True, metavar="SPLIT=PATH")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--pilot-surah", type=int, default=1)
    args = parser.parse_args()
    sources = []
    for source in args.source:
        split, separator, path = source.partition("=")
        if not separator or not split or not path:
            parser.error("--source must be SPLIT=PATH")
        sources.append((split, Path(path)))
    count = build_catalog(sources, args.output_dir.resolve(), args.pilot_surah)
    print(f"Indexed {count} unverified reference recordings in {args.output_dir}")


if __name__ == "__main__":
    main()
