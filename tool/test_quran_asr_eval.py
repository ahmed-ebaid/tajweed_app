import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch
import subprocess

from quran_asr_eval import (
    MAX_SECONDS, SAMPLE_RATE, read_pcm, reference_metrics, transcribe_native,
)


class RecognitionEvaluationTest(unittest.TestCase):
    def test_expected_scripture_is_not_reported_as_ground_truth_wer(self):
        metrics = reference_metrics(
            "كَذَّبَتْ ثَمُودُ بِطَغْوَاهَا", "كذبت ثمود بصقواها", "expected",
        )
        self.assertEqual(metrics["word_edits"], 1)
        self.assertEqual(metrics["exact_prefix_words"], 2)
        self.assertAlmostEqual(metrics["target_edit_rate"], 1 / 3)
        self.assertNotIn("word_error_rate", metrics)
        self.assertFalse(metrics["normalized_exact_match"])

    def test_preserves_substitutions_insertions_and_omissions(self):
        for spoken in (
            "ناقط الله وسقياها", "الله وسقياها", "ناقة الله خطأ وسقياها",
        ):
            with self.subTest(spoken=spoken):
                result = reference_metrics("ناقة الله وسقياها", spoken, "transcribed")
                self.assertEqual(result["word_edits"], 1)
                self.assertAlmostEqual(result["word_error_rate"], 1 / 3)
                self.assertFalse(result["normalized_exact_match"])

    def test_diacritics_normalize_without_rewriting_consonants(self):
        result = reference_metrics(
            "نَاقَةَ ٱللَّهِ وَسُقْيَاهَا", "ناقة الله وسقياها", "transcribed",
        )
        self.assertTrue(result["normalized_exact_match"])
        self.assertEqual(result["word_error_rate"], 0)
        for reference, kind in [("", "expected"), ("الله", "unverified")]:
            with self.assertRaises(ValueError):
                reference_metrics(reference, "الله", kind)

    @patch("quran_asr_eval.subprocess.run")
    def test_native_replay_has_no_text_prompt_or_decoding_fallback(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, b" transcript \n", b"")
        report = transcribe_native(Path("clip.wav"), Path("whisper-cli"), Path("model.bin"), 4)
        command = run.call_args.args[0]
        self.assertNotIn("--prompt", command)
        self.assertIn("-nf", command)
        self.assertEqual(command[command.index("-mc") + 1], "0")
        self.assertEqual(command[command.index("-bs") + 1], "4")
        self.assertTrue(run.call_args.kwargs["check"])
        self.assertEqual(report["transcript"], "transcript")
        self.assertEqual(report["beam_size"], 4)

    @patch("quran_asr_eval.subprocess.run")
    def test_invalid_native_text_is_not_replaced_into_matchable_words(self, run):
        raw = b"\xd8\xaa\xd9\x8e\xb8"
        run.return_value = subprocess.CompletedProcess([], 0, raw, b"")
        with self.assertRaises(UnicodeDecodeError) as caught:
            transcribe_native(Path("clip.wav"), Path("whisper-cli"), Path("model.bin"), 1)
        self.assertEqual(caught.exception.object, raw)

    @patch("quran_asr_eval.subprocess.run")
    def test_decoder_failures_are_not_success_shaped_results(self, run):
        run.side_effect = subprocess.CalledProcessError(1, ["whisper-cli"])
        with self.assertRaises(subprocess.CalledProcessError):
            transcribe_native(Path("clip.wav"), Path("whisper-cli"), Path("model.bin"), 1)
        with self.assertRaises(ValueError):
            transcribe_native(Path("clip.wav"), Path("whisper-cli"), Path("model.bin"), 0)


class AudioInputTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "clip.wav"

    def write(self, frames, channels=1, width=2, rate=SAMPLE_RATE):
        with wave.open(str(self.path), "wb") as audio:
            audio.setnchannels(channels)
            audio.setsampwidth(width)
            audio.setframerate(rate)
            audio.writeframes(bytes(frames * channels * width))

    def test_accepts_exact_thirty_second_boundary(self):
        self.write(SAMPLE_RATE * MAX_SECONDS)
        self.assertEqual(len(read_pcm(self.path)), SAMPLE_RATE * MAX_SECONDS * 2)

    def test_rejects_empty_and_overlong(self):
        for frames in (0, SAMPLE_RATE * MAX_SECONDS + 1):
            with self.subTest(frames=frames):
                self.write(frames)
                with self.assertRaisesRegex(ValueError, "nonempty clip"):
                    read_pcm(self.path)

    def test_rejects_wrong_format(self):
        for options in ({"channels": 2}, {"width": 1}, {"rate": 44100}):
            with self.subTest(options=options):
                self.write(16, **options)
                with self.assertRaisesRegex(ValueError, "PCM16"):
                    read_pcm(self.path)

    def test_rejects_truncated_payload(self):
        self.write(100)
        content = self.path.read_bytes()
        self.path.write_bytes(content[:-2])
        with self.assertRaisesRegex(ValueError, "truncated"):
            read_pcm(self.path)


if __name__ == "__main__":
    unittest.main()
