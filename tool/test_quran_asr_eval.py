import tempfile
import unittest
import wave
from pathlib import Path

from quran_asr_eval import MAX_SECONDS, SAMPLE_RATE, read_pcm


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
