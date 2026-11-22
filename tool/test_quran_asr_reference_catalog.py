import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from quran_asr_reference_catalog import build_catalog


class ReferenceCatalogTest(unittest.TestCase):
    def make_source(self, root, reciter=6):
        source = root / str(reciter)
        (source / "results" / str(reciter)).mkdir(parents=True)
        (source / "cache" / str(reciter)).mkdir(parents=True)
        (source / "manifest.json").write_text(json.dumps({
            "reciters": [{"id": reciter, "reciter_name": "Reciter"}],
            "verse_keys": ["1:1"],
            "model_sha256": "model",
            "preview_step_seconds": 4,
        }))
        (source / "cache" / str(reciter) / "001-001.mp3").write_bytes(b"audio")
        (source / "results" / str(reciter) / "001-001.json").write_text(json.dumps({
            "reciter_id": reciter,
            "reciter_name": "Reciter",
            "verse_key": "1:1",
            "expected_text": "بسم الله",
            "audio_url": "https://example.test/1.mp3",
            "audio_sha256": hashlib.sha256(b"audio").hexdigest(),
            "status": "ok",
            "snapshots": [],
        }))
        return source

    def test_build_keeps_reference_unverified_and_creates_pilot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.make_source(root)
            output = root / "output"
            self.assertEqual(build_catalog([("development", source)], output, 1), 1)
            row = json.loads((output / "reference-catalog.jsonl").read_text())
            self.assertEqual(row["label"], "reference_recitation_unverified")
            self.assertEqual(row["review_status"], "not_reviewed")
            self.assertEqual(row["split"], "development")
            self.assertTrue(Path(row["audio_path"]).is_file())
            self.assertTrue((output / "pilot/results/6/001-001.json").is_file())
            self.assertEqual(json.loads((output / "pilot/manifest.json").read_text())["verse_keys"], ["1:1"])

    def test_incomplete_or_duplicate_sources_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self.make_source(root)
            with self.assertRaisesRegex(ValueError, "multiple splits"):
                build_catalog([("development", source), ("heldout", source)], root / "duplicate", 1)
            self.assertFalse((root / "duplicate/pilot").exists())
            (source / "cache/6/001-001.mp3").write_bytes(b"corrupted")
            with self.assertRaisesRegex(ValueError, "Audio hash does not match"):
                build_catalog([("development", source)], root / "corrupted", 1)
            (source / "cache/6/001-001.mp3").unlink()
            with self.assertRaisesRegex(ValueError, "Missing audio"):
                build_catalog([("development", source)], root / "missing", 1)


if __name__ == "__main__":
    unittest.main()
