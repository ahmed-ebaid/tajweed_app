import tempfile
import unittest
import urllib.error
import wave
from pathlib import Path
from unittest.mock import patch

from quran_asr_corpus_eval import audio_url, download, replay, snapshot_ranges
from quran_asr_eval import SAMPLE_RATE


class CorpusEvaluationTest(unittest.TestCase):
    @patch("quran_asr_corpus_eval.transcribe_native")
    @patch("quran_asr_corpus_eval.subprocess.run")
    def test_bad_utf8_is_explicit_and_does_not_skip_the_rest_of_the_audio(self, convert, decode):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)

            def write_audio(*args, **kwargs):
                with wave.open(str(work / "decoded.wav"), "wb") as audio:
                    audio.setnchannels(1)
                    audio.setsampwidth(2)
                    audio.setframerate(SAMPLE_RATE)
                    audio.writeframes(bytes(5 * SAMPLE_RATE * 2))

            convert.side_effect = write_audio
            decode.side_effect = [
                UnicodeDecodeError("utf-8", b"\xb8", 0, 1, "invalid start byte"),
                {"transcript": "الله", "elapsed_seconds_including_model_load": 0.1},
            ]
            duration, snapshots = replay(Path("source.mp3"), Path("cli"), Path("model"), 4, work)
            self.assertEqual(duration, 5)
            self.assertEqual(len(snapshots), 2)
            self.assertIsNone(snapshots[0]["transcript"])
            self.assertEqual(snapshots[0]["decoder_error"], "invalid_utf8")
            self.assertEqual(snapshots[0]["raw_decoder_stdout_hex"], "b8")
            self.assertEqual(snapshots[1]["transcript"], "الله")
            self.assertTrue(snapshots[1]["final"])

    def test_short_clip_has_one_full_final_snapshot(self):
        self.assertEqual(list(snapshot_ranges(3 * SAMPLE_RATE, 4)), [
            (0, 3 * SAMPLE_RATE, True),
        ])

    def test_long_clip_preserves_rolling_previews_and_bounded_final_tail(self):
        snapshots = list(snapshot_ranges(61 * SAMPLE_RATE, 4))
        self.assertEqual(snapshots[0], (0, 4 * SAMPLE_RATE, False))
        self.assertEqual(snapshots[2], (4 * SAMPLE_RATE, 12 * SAMPLE_RATE, False))
        self.assertEqual(snapshots[-1], (31 * SAMPLE_RATE, 61 * SAMPLE_RATE, True))
        self.assertEqual(sum(final for _, _, final in snapshots), 1)
        self.assertTrue(all(end - start <= 8 * SAMPLE_RATE for start, end, final in snapshots if not final))
        self.assertTrue(all(a[1] < b[1] for a, b in zip(snapshots, snapshots[1:])))

    def test_audio_urls_preserve_external_mirrors_and_reject_plain_http(self):
        self.assertEqual(audio_url("Alafasy/mp3/091011.mp3"), "https://verses.quran.com/Alafasy/mp3/091011.mp3")
        self.assertEqual(audio_url("//mirrors.quranicaudio.com/example.mp3"), "https://mirrors.quranicaudio.com/example.mp3")
        with self.assertRaises(ValueError):
            audio_url("http://example.com/audio.mp3")

    @patch("quran_asr_corpus_eval.time.sleep")
    @patch("quran_asr_corpus_eval.urllib.request.urlopen")
    def test_failed_download_is_not_cached_as_success(self, fetch, sleep):
        fetch.side_effect = urllib.error.URLError("unavailable")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audio.mp3"
            with self.assertRaises(urllib.error.URLError):
                download("https://example.com/audio.mp3", path)
            self.assertFalse(path.exists())
            self.assertEqual(fetch.call_count, 3)


if __name__ == "__main__":
    unittest.main()
