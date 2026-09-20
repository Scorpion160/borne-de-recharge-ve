import csv
import io
import unittest

from exports import trusted_telemetry_csv


class FakePool:
    def __init__(self) -> None:
        self.query = ""
        self.args = ()

    async def fetch(self, query, *args):
        self.query = query
        self.args = args
        return []


class FakeDatabase:
    def __init__(self) -> None:
        self.available = True
        self.pool = FakePool()


class TrustedExportTests(unittest.IsolatedAsyncioTestCase):
    async def test_trusted_export_reads_only_trusted_view(self) -> None:
        database = FakeDatabase()
        content = await trusted_telemetry_csv(database, "borne-01", "24h")

        self.assertIn("FROM telemetry_ac_trusted", database.pool.query)
        self.assertIn("telemetry_trust_registry", database.pool.query)
        self.assertIn("r.status = 'TRUSTED'", database.pool.query)
        self.assertEqual(database.pool.args[0], "borne-01")

        reader = csv.reader(io.StringIO(content.lstrip("\ufeff")), delimiter=";")
        header = next(reader)
        self.assertEqual(header[0], "trust_state")
        self.assertIn("sample_id", header)
        self.assertIn("boot_id", header)
        self.assertIn("sequence", header)
        self.assertIn("quality", header)
        self.assertIn("validation_note", header)
        self.assertEqual(list(reader), [])


if __name__ == "__main__":
    unittest.main()
