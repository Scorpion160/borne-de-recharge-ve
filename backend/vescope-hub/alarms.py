from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class AlarmEngine:
    def __init__(self) -> None:
        self.low_voltage_v = float(os.getenv("VESCOPE_LOW_VOLTAGE_V", "207"))
        self.high_voltage_v = float(os.getenv("VESCOPE_HIGH_VOLTAGE_V", "253"))
        self.low_power_factor = float(os.getenv("VESCOPE_LOW_POWER_FACTOR", "0.90"))
        self.low_frequency_hz = float(os.getenv("VESCOPE_LOW_FREQUENCY_HZ", "49.0"))
        self.high_frequency_hz = float(os.getenv("VESCOPE_HIGH_FREQUENCY_HZ", "51.0"))
        self.stale_after_s = float(os.getenv("VESCOPE_STALE_AFTER_S", "5"))
        self._active: dict[tuple[str, str], bool] = {}

    def evaluate_telemetry(self, device_id: str, payload: dict[str, Any]) -> list[dict[str, Any]]:
        alerts: list[dict[str, Any]] = []

        voltage = payload.get("voltage_v")
        if isinstance(voltage, (int, float)):
            alerts.extend(
                self._transition(
                    device_id,
                    "AC_LOW_VOLTAGE",
                    voltage < self.low_voltage_v,
                    "WARNING",
                    "Tension secteur inférieure au seuil configuré",
                    float(voltage),
                    self.low_voltage_v,
                    "pzem_ac",
                    "Tension secteur revenue dans la plage normale",
                )
            )
            alerts.extend(
                self._transition(
                    device_id,
                    "AC_HIGH_VOLTAGE",
                    voltage > self.high_voltage_v,
                    "WARNING",
                    "Tension secteur supérieure au seuil configuré",
                    float(voltage),
                    self.high_voltage_v,
                    "pzem_ac",
                    "Tension secteur revenue dans la plage normale",
                )
            )

        power_factor = payload.get("power_factor")
        if isinstance(power_factor, (int, float)) and float(power_factor) > 0:
            alerts.extend(
                self._transition(
                    device_id,
                    "AC_LOW_POWER_FACTOR",
                    power_factor < self.low_power_factor,
                    "WARNING",
                    "Facteur de puissance inférieur au seuil configuré",
                    float(power_factor),
                    self.low_power_factor,
                    "pzem_ac",
                    "Facteur de puissance revenu dans la plage normale",
                )
            )

        frequency = payload.get("frequency_hz")
        if isinstance(frequency, (int, float)):
            out_of_range = frequency < self.low_frequency_hz or frequency > self.high_frequency_hz
            threshold = self.low_frequency_hz if frequency < self.low_frequency_hz else self.high_frequency_hz
            alerts.extend(
                self._transition(
                    device_id,
                    "AC_FREQUENCY_OUT_OF_RANGE",
                    out_of_range,
                    "WARNING",
                    "Fréquence secteur hors de la plage configurée",
                    float(frequency),
                    threshold,
                    "pzem_ac",
                    "Fréquence secteur revenue dans la plage normale",
                )
            )

        quality = payload.get("quality")
        alerts.extend(
            self._transition(
                device_id,
                "AC_DATA_QUALITY",
                quality not in (None, "GOOD", "ESTIMATED"),
                "WARNING",
                f"Qualité de donnée AC dégradée : {quality}",
                None,
                None,
                "pzem_ac",
                "Qualité de donnée AC redevenue correcte",
            )
        )

        return alerts

    def evaluate_staleness(self, device_id: str, age_s: float) -> list[dict[str, Any]]:
        return self._transition(
            device_id,
            "AC_TELEMETRY_STALE",
            age_s > self.stale_after_s,
            "ALERT",
            "Télémétrie AC trop ancienne ou interrompue",
            round(age_s, 1),
            self.stale_after_s,
            "vescope_hub",
            "Réception de la télémétrie AC rétablie",
        )

    def _transition(
        self,
        device_id: str,
        code: str,
        condition: bool,
        severity: str,
        message: str,
        value: float | None,
        threshold: float | None,
        source: str,
        recovery_message: str,
    ) -> list[dict[str, Any]]:
        key = (device_id, code)
        was_active = self._active.get(key, False)

        if condition and not was_active:
            self._active[key] = True
            return [
                {
                    "schema": 1,
                    "device_id": device_id,
                    "timestamp": now_iso(),
                    "severity": severity,
                    "code": code,
                    "message": message,
                    "value": value,
                    "threshold": threshold,
                    "source": source,
                    "generated_by": "vescope_hub",
                }
            ]

        if not condition and was_active:
            self._active[key] = False
            return [
                {
                    "schema": 1,
                    "device_id": device_id,
                    "timestamp": now_iso(),
                    "severity": "INFO",
                    "code": f"{code}_RECOVERED",
                    "message": recovery_message,
                    "value": value,
                    "threshold": threshold,
                    "source": source,
                    "generated_by": "vescope_hub",
                }
            ]

        return []
