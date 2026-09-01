from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from scripts.validate_catalog_export import load_contract, validate_contract

REPO_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = REPO_ROOT / "catalog-export.json"


class CatalogExportContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contract = load_contract(CONTRACT_PATH)

    def test_real_contract_is_valid(self) -> None:
        self.assertEqual(validate_contract(REPO_ROOT, self.contract), [])

    def test_rejects_unpinned_export_mode(self) -> None:
        changed = copy.deepcopy(self.contract)
        changed["destination"]["mode"] = "editable-copy"
        errors = validate_contract(REPO_ROOT, changed)
        self.assertIn("destination.mode must be pinned-generated-export", errors)

    def test_rejects_path_traversal(self) -> None:
        changed = copy.deepcopy(self.contract)
        changed["export"]["include"][0] = "../secret.env"
        errors = validate_contract(REPO_ROOT, changed)
        self.assertIn("export.include must contain only normalized relative paths", errors)

    def test_rejects_missing_source_file(self) -> None:
        changed = copy.deepcopy(self.contract)
        changed["export"]["include"].append("zzz-missing.txt")
        changed["export"]["include"].sort()
        errors = validate_contract(REPO_ROOT, changed)
        self.assertTrue(any("included file does not exist" in error for error in errors))

    def test_contract_is_machine_readable_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            copy_path = Path(directory) / "catalog-export.json"
            copy_path.write_text(json.dumps(self.contract), encoding="utf-8")
            self.assertEqual(load_contract(copy_path)["packageId"], "mortagate-cowork")


if __name__ == "__main__":
    unittest.main()
