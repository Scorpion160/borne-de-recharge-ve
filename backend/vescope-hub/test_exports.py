import csv
import io
import unittest
from datetime import datetime, timezone

from exports import session_telemetry_csv, trusted_telemetry_csv


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


class FakeSessionPool(FakePool):
    def __init__(self, exact_rows=None, fallback_rows=None):
        super().__init__()
        self.started = datetime(2026, 9, 18, 11, 58, tzinfo=timezone.utc)
        self.ended = datetime(2026, 9, 18, 12, 14, tzinfo=timezone.utc)
        self.exact_rows = exact_rows or []
        self.fallback_rows = fallback_rows or []
        self.queries = []

    async def fetchrow(self, query, *args):
        self.queries.append((query, args))
        if args != ("borne-01", "VE01-20260918-115811"):
            return None
        return {"started_at": self.started, "ended_at": self.ended}

    async def fetch(self, query, *args):
        self.queries.append((query, args))
        return self.fallback_rows if "session_id IS NULL" in query else self.exact_rows


class SessionMeasurementsTests(unittest.IsolatedAsyncioTestCase):
    def _row(self, session_id):
        return {
            "measured_at": datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc),
            "received_at": datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc),
            "sample_id": "sample-1", "boot_id": 123, "sequence": 1,
            "session_id": session_id, "voltage_v": 230, "current_a": 15,
            "active_power_w": 3400, "power_factor": 0.9,
            "frequency_hz": 50, "energy_total_wh": 200,
        }

    async def test_export_uses_linked_samples_before_time_fallback(self):
        database = FakeDatabase()
        database.pool = FakeSessionPool(exact_rows=[self._row("VE01-20260918-115811")])
        result = await session_telemetry_csv(database, "borne-01", "VE01-20260918-115811")
        rows = list(csv.DictReader(io.StringIO(result.lstrip("\ufeff")), delimiter=";"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["association"], "session_id")
        self.assertEqual(rows[0]["active_power_w"], "3400")
        self.assertEqual(len(database.pool.queries), 2)

    async def test_old_untagged_samples_are_limited_to_session_dates(self):
        database = FakeDatabase()
        database.pool = FakeSessionPool(fallback_rows=[self._row(None)])
        result = await session_telemetry_csv(database, "borne-01", "VE01-20260918-115811")
        rows = list(csv.DictReader(io.StringIO(result.lstrip("\ufeff")), delimiter=";"))
        self.assertEqual(rows[0]["association"], "plage_horaire")
        fallback_query, args = database.pool.queries[-1]
        self.assertIn("session_id IS NULL", fallback_query)
        self.assertIn("measured_at >= $2", fallback_query)
        self.assertEqual(args, ("borne-01", database.pool.started, database.pool.ended))

    async def test_session_cannot_be_exported_for_another_device(self):
        database = FakeDatabase()
        database.pool = FakeSessionPool(exact_rows=[self._row("VE01-20260918-115811")])
        with self.assertRaises(LookupError):
            await session_telemetry_csv(database, "borne-02", "VE01-20260918-115811")
        self.assertEqual(len(database.pool.queries), 1)


if __name__ == "__main__":
    unittest.main()
