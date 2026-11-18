"""Local-only, short-clip Quran ASR evaluation; not a memorization grader."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time
import wave


MODELS = (
    "tarteel-ai/whisper-tiny-ar-quran",
    "tarteel-ai/whisper-base-ar-quran",
)
SAMPLE_RATE = 16000
MAX_SECONDS = 30


def reference_metrics(reference, transcript, reference_kind):
    """Expected scripture is a target, not a human transcript of the audio."""
    if reference_kind not in ("expected", "transcribed"):
        raise ValueError("Reference kind must be expected or transcribed.")

    def words(text):
        text = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]", "", text)
        text = text.replace("\u0671", "\u0627")
        return re.findall(r"[\u0621-\u063A\u0641-\u064A]+", text)

    expected = words(reference)
    actual = words(transcript)
    if not expected:
        raise ValueError("Reference must contain Arabic words.")
    previous = list(range(len(actual) + 1))
    for row, word in enumerate(expected, 1):
        current = [row]
        for column, spoken in enumerate(actual, 1):
            current.append(min(
                previous[column] + 1,
                current[column - 1] + 1,
                previous[column - 1] + (word != spoken),
            ))
        previous = current
    prefix = 0
    for wanted, spoken in zip(expected, actual):
        if wanted != spoken:
            break
        prefix += 1
    return {
        "reference_kind": reference_kind,
        "reference_words": len(expected),
        "transcript_words": len(actual),
        "word_edits": previous[-1],
        "exact_prefix_words": prefix,
        "normalized_exact_match": expected == actual,
        "word_error_rate" if reference_kind == "transcribed" else "target_edit_rate":
            previous[-1] / len(expected),
    }


def transcribe_native(audio, cli, model, beam_size):
    """Replay the shipping decoder locally, with no expected-text prompt."""
    if not 1 <= beam_size <= 16:
        raise ValueError("Beam size must be between 1 and 16.")
    command = [
        str(cli.resolve()), "-m", str(model.resolve()), "-f", str(audio.resolve()),
        "-l", "ar", "-t", "4", "-bs", str(beam_size), "-bo", "1",
        "-nf", "-nt", "-np", "-mc", "0", "-ng",
    ]
    started = time.monotonic()
    result = subprocess.run(
        command, capture_output=True, timeout=120, check=True,
    )
    return {
        "backend": "whisper.cpp",
        "model": str(model),
        "beam_size": beam_size,
        "gpu": False,
        "elapsed_seconds_including_model_load": round(time.monotonic() - started, 3),
        "transcript": result.stdout.decode("utf-8").strip(),
        "notice": "Local raw decoding without reference prompting or word corrections. "
                  "Desktop latency does not predict physical-iPhone latency.",
    }


def read_pcm(path):
    with wave.open(str(path), "rb") as audio:
        if (
            audio.getnchannels() != 1
            or audio.getsampwidth() != 2
            or audio.getframerate() != SAMPLE_RATE
            or audio.getcomptype() != "NONE"
        ):
            raise ValueError("Audio must be mono, uncompressed PCM16 WAV at 16000 Hz.")
        frames = audio.getnframes()
        if not 0 < frames <= SAMPLE_RATE * MAX_SECONDS:
            raise ValueError("Supply a nonempty clip of at most 30 seconds.")
        pcm = audio.readframes(frames)
        if len(pcm) != frames * 2:
            raise ValueError("WAV payload is truncated.")
        return pcm


def transcribe(pcm, model_name, cache_dir, offline):
    # Model downloads are allowed, but user audio never leaves this process.
    os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
    os.environ["DO_NOT_TRACK"] = "1"
    import numpy as np
    import torch
    from transformers import WhisperForConditionalGeneration, WhisperProcessor

    samples = np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768
    load_options = {"cache_dir": cache_dir, "local_files_only": offline}
    processor = WhisperProcessor.from_pretrained(model_name, **load_options)
    model = WhisperForConditionalGeneration.from_pretrained(
        model_name, **load_options
    )
    model.eval()
    inputs = processor(
        samples,
        sampling_rate=SAMPLE_RATE,
        return_tensors="pt",
        return_attention_mask=True,
    )
    prompt = processor.get_decoder_prompt_ids(language="ar", task="transcribe")
    decoder_input_ids = torch.tensor(
        [[model.config.decoder_start_token_id] + [token for _, token in prompt]]
    )
    started = time.monotonic()
    with torch.inference_mode():
        tokens = model.generate(
            input_features=inputs.input_features,
            attention_mask=inputs.attention_mask,
            decoder_input_ids=decoder_input_ids,
            do_sample=False,
        )
    elapsed = time.monotonic() - started
    return {
        "model": model_name,
        "model_revision": getattr(model.config, "_commit_hash", None),
        "duration_seconds": len(samples) / SAMPLE_RATE,
        "inference_seconds": round(elapsed, 3),
        "transcript": processor.batch_decode(tokens, skip_special_tokens=True)[0].strip(),
        "silent_input": not bool(np.any(samples)),
        "confirmed_ayahs": None,
        "notice": (
            "Unverified model transcript, not evidence of correct recitation. "
            "Quran-trained ASR can hallucinate or correct omitted/incorrect words. "
            "This prototype does not grade Tajweed or advance Hifz progress."
        ),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audio", type=Path, help="Explicit local PCM16 mono 16 kHz WAV")
    parser.add_argument("--model", choices=MODELS, default=MODELS[0])
    parser.add_argument("--cache-dir", help="Private model cache directory (HF backend)")
    parser.add_argument("--offline", action="store_true", help="Disallow model downloads")
    parser.add_argument("--native-cli", type=Path, help="Existing local whisper-cli executable")
    parser.add_argument("--native-model", type=Path, help="Existing local ggml model file")
    parser.add_argument("--beam-size", type=int, default=1, help="Native decoder beam size, 1-16")
    parser.add_argument("--reference", help="Optional Arabic evaluation reference; never sent to decoder")
    parser.add_argument(
        "--reference-kind", choices=("expected", "transcribed"), default="expected",
        help="Use transcribed only for an independently checked transcript of this audio",
    )
    args = parser.parse_args()
    if bool(args.native_cli) != bool(args.native_model):
        parser.error("--native-cli and --native-model must be supplied together")
    if not args.native_cli and not args.cache_dir:
        parser.error("--cache-dir is required for the Hugging Face backend")
    try:
        pcm = read_pcm(args.audio)
    except (OSError, EOFError, wave.Error, ValueError) as error:
        parser.exit(2, f"Invalid audio: {error}\n")
    try:
        if args.native_cli:
            report = transcribe_native(
                args.audio, args.native_cli, args.native_model, args.beam_size,
            )
            report["duration_seconds"] = len(pcm) / (SAMPLE_RATE * 2)
            report["silent_input"] = not any(pcm)
        else:
            report = transcribe(pcm, args.model, args.cache_dir, args.offline)
        if args.reference:
            report["evaluation"] = reference_metrics(
                args.reference, report["transcript"], args.reference_kind,
            )
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Evaluation failed: {error}\n")
    except ImportError as error:
        parser.exit(
            1,
            f"Missing inference dependency: {error}. "
            "Install tool/quran_asr_requirements.txt in a separate virtualenv.\n",
        )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
