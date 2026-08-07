from __future__ import annotations

import os
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


@dataclass
class AlarmSettings:
    low_voltage_v: float
    high_voltage_v: float
    low_power_factor: float
    low_frequency_hz: float
    high_frequency_hz: float
    stale_after_s: float

    def as_dict(self) -> dict[str, float]:
        return asdict(self)


class AlarmEngine:
    def __init__(self) -> None:
        self.defaults = AlarmSettings(
            low_voltage_v=float(os.getenv("VESCOPE_LOW_VOLTAGE_V", "207")),
            high_voltage_v=float(os.getenv("VESCOPE_HIGH_VOLTAGE_V", "253")),
            low_power_factor=float(os.getenv("VESCOPE_LOW_POWER_FACTOR", "0.90")),
            low_frequency_hz=float(os.getenv("VESCOPE_LOW_FREQUENCY_HZ", "49.0")),
            high_frequency_hz=float(os.getenv("VESCOPE_HIGH_FREQUENCY_HZ", "51.0")),
            stale_after_s=float(os.getenv("VESCOPE_STALE_AFTER_S", "5")),
        )
        self._settings: dict[str, AlarmSettings] = {}
        self._active: dict[tuple[str, str], bool] = {}

    def get_settings(self, device_id: str) -> AlarmSettings:
        return self._settings.get(device_id, self.defaults)

    def configure(self, device_id: str, values: dict[str, Any] | None) -> AlarmSettings:
        if not values:
            self._settings[device_id] = AlarmSettings(**self.defaults.as_dict())
            return self._settings[device_id]

        base = self.defaults.as_dict()
        for key in base:
            if values.get(key) is not None:
                base[key] = float(values[key])
        settings = AlarmSettings(**base)
        self.validate(settings)
        self._settings[device_id] = settings
        return settings

    @staticmethod
    def validate(settings: AlarmSettings) -> None:
        if not 100 <= settings.low_voltage_v < settings.high_voltage_v <= 300:
            raise ValueError("La plage de tension doit respecter 100 <= Umin < Umax <= 300 V")
        if not 0.1 <= settings.low_power_factor <= 1.0:
            raise ValueError("Le facteur de puissance minimal doit être compris entre 0,1 et 1,0")
        if not 40 <= settings.low_frequency_hz < settings.high_frequency_hz <= 70:
            raise ValueError("La plage de fréquence doit respecter 40 <= fmin < fmax <= 70 Hz")
        if not 2 <= settings.stale_after_s <= 300:
            raise ValueError("Le délai de perte de télémétrie doit être compris entre 2 et 300 s")

    def evaluate_telemetry(self, device_id: str, payload: dict[str, Any]) -> list[dict[str, Any]]:
        alerts: list[dict[str, Any]] = []
        settings = self.get_settings(device_id)

        voltage = payload.get("voltage_v")
        if isinstance(voltage, (int, float)):
            alerts.extend(
                self._transition(
                    device_id,
                    "AC_LOW_VOLTAGE",
                    voltage < settings.low_voltage_v,
                    "WARNING",
                    "Tension secteur inférieure au seuil configuré",
                    float(voltage),
                    settings.low_voltage_v,
                    "pzem_ac",
                    "Tension secteur revenue dans la plage normale",
                )
            )
            alerts.extend(
                self._transition(
                    device_id,
                    "AC_HIGH_VOLTAGE",
                    voltage > settings.high_voltage_v,
                    "WARNING",
                    "Tension secteur supérieure au seuil configuré",
                    float(voltage),
                    settings.high_voltage_v,
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
                    power_factor < settings.low_power_factor,
                    "WARNING",
                    "Facteur de puissance inférieur au seuil configuré",
                    float(power_factor),
                    settings.low_power_factor,
                    "pzem_ac",
                    "Facteur de puissance revenu dans la plage normale",
                )
            )

        frequency = payload.get("frequency_hz")
        if isinstance(frequency, (int, float)):
            out_of_range = frequency < settings.low_frequency_hz or frequency > settings.high_frequency_hz
            threshold = settings.low_frequency_hz if frequency < settings.low_frequency_hz else settings.high_frequency_hz
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
        settings = self.get_settings(device_id)
        return self._transition(
            device_id,
            "AC_TELEMETRY_STALE",
            age_s > settings.stale_after_s,
            "ALERT",
            "Télémétrie AC trop ancienne ou interrompue",
            round(age_s, 1),
            settings.stale_after_s,
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
            return [{
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
            }]

        if not condition and was_active:
            self._active[key] = False
            return [{
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
            }]

        return []
