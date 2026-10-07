from pathlib import Path
import unittest

from byte_contract import validate_canonical_json_file


class TestCanonicalJsonWorkspace(unittest.TestCase):
    def test_tracked_uac_json_files_are_canonical_bytes(self):
        uac_root = Path(__file__).resolve().parents[1]
        json_files = sorted(uac_root.rglob("*.json"))
        self.assertGreater(len(json_files), 0)
        for path in json_files:
            with self.subTest(path=str(path.relative_to(uac_root))):
                validate_canonical_json_file(path)


if __name__ == "__main__":
    unittest.main()
