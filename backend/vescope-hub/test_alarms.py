import unittest

from alarms import AlarmEngine


class AlarmEngineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.engine = AlarmEngine()

    def base_payload(self) -> dict:
        return {
            "quality": "GOOD",
            "voltage_v": 230.0,
            "power_factor": 0.97,
            "frequency_hz": 50.0,
        }

    def test_alarm_is_emitted_once_then_recovers(self) -> None:
        payload = self.base_payload()
        payload["power_factor"] = 0.80

        first = self.engine.evaluate_telemetry("borne-01", payload)
        second = self.engine.evaluate_telemetry("borne-01", payload)

        self.assertTrue(any(item["code"] == "AC_LOW_POWER_FACTOR" for item in first))
        self.assertFalse(any(item["code"] == "AC_LOW_POWER_FACTOR" for item in second))

        payload["power_factor"] = 0.97
        recovery = self.engine.evaluate_telemetry("borne-01", payload)
        self.assertTrue(any(item["code"] == "AC_LOW_POWER_FACTOR_RECOVERED" for item in recovery))

    def test_stale_alarm_transition(self) -> None:
        stale_after = self.engine.get_settings("borne-01").stale_after_s
        self.assertEqual(self.engine.evaluate_staleness("borne-01", 1.0), [])
        alert = self.engine.evaluate_staleness("borne-01", stale_after + 1)
        self.assertEqual(alert[0]["code"], "AC_TELEMETRY_STALE")
        self.assertEqual(self.engine.evaluate_staleness("borne-01", stale_after + 2), [])
        recovery = self.engine.evaluate_staleness("borne-01", 0.5)
        self.assertEqual(recovery[0]["code"], "AC_TELEMETRY_STALE_RECOVERED")

    def test_device_specific_settings_are_applied(self) -> None:
        self.engine.configure(
            "borne-01",
            {
                "low_voltage_v": 220,
                "high_voltage_v": 240,
                "low_power_factor": 0.95,
                "low_frequency_hz": 49.5,
                "high_frequency_hz": 50.5,
                "stale_after_s": 10,
            },
        )
        payload = self.base_payload()
        payload["voltage_v"] = 215
        alerts = self.engine.evaluate_telemetry("borne-01", payload)
        self.assertTrue(any(item["code"] == "AC_LOW_VOLTAGE" and item["threshold"] == 220 for item in alerts))
        self.assertEqual(self.engine.evaluate_staleness("borne-01", 6), [])

    def test_invalid_ranges_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            self.engine.configure(
                "borne-01",
                {
                    "low_voltage_v": 260,
                    "high_voltage_v": 250,
                    "low_power_factor": 0.9,
                    "low_frequency_hz": 49,
                    "high_frequency_hz": 51,
                    "stale_after_s": 5,
                },
            )


if __name__ == "__main__":
    unittest.main()
