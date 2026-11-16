"""Local-only, short-clip Quran ASR evaluation; not a memorization grader."""

import argparse
import json
import os
from pathlib import Path
import time
import wave


MODELS = (
    "tarteel-ai/whisper-tiny-ar-quran",
    "tarteel-ai/whisper-base-ar-quran",
)
SAMPLE_RATE = 16000
MAX_SECONDS = 30


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
    parser.add_argument("--cache-dir", required=True, help="Private model cache directory")
    parser.add_argument("--offline", action="store_true", help="Disallow model downloads")
    args = parser.parse_args()
    try:
        pcm = read_pcm(args.audio)
    except (OSError, EOFError, wave.Error, ValueError) as error:
        parser.exit(2, f"Invalid audio: {error}\n")
    try:
        report = transcribe(pcm, args.model, args.cache_dir, args.offline)
    except ImportError as error:
        parser.exit(
            1,
            f"Missing inference dependency: {error}. "
            "Install tool/quran_asr_requirements.txt in a separate virtualenv.\n",
        )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
