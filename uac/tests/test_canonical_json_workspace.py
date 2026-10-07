from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from byte_contract import validate_canonical_json_file


class TestCanonicalJsonWorkspace(unittest.TestCase):
    def test_tracked_uac_json_files_are_canonical_bytes(self):
        json_files = sorted(ROOT.rglob("*.json"))
        self.assertGreater(len(json_files), 0)
        for path in json_files:
            with self.subTest(path=str(path.relative_to(ROOT))):
                validate_canonical_json_file(path)


if __name__ == "__main__":
    unittest.main()
