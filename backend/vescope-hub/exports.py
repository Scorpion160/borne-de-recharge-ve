from __future__ import annotations

import csv
import io
from typing import Any

from storage import Database


RANGES = {
    "1h": ("1 hour", None),
    "24h": ("24 hours", None),
    "7d": ("7 days", "1 minute"),
    "30d": ("30 days", "5 minutes"),
}


def _csv_buffer() -> tuple[io.StringIO, csv.writer]:
    stream = io.StringIO()
    stream.write("\ufeff")
    return stream, csv.writer(stream, delimiter=";", lineterminator="\r\n")


async def telemetry_csv(database: Database, device_id: str, range_key: str) -> str:
    if not database.available or database.pool is None:
        raise RuntimeError("PostgreSQL indisponible")

    interval, bucket = RANGES[range_key]
    stream, writer = _csv_buffer()
    writer.writerow([
        "timestamp_utc",
        "voltage_v",
        "current_a",
        "active_power_w",
        "power_factor",
        "frequency_hz",
        "energy_total_wh",
        "samples",
        "resolution",
    ])

    if bucket is None:
        rows = await database.pool.fetch(
            """
            SELECT measured_at AS timestamp_utc, voltage_v, current_a, active_power_w,
                   power_factor, frequency_hz, energy_total_wh
            FROM telemetry_ac
            WHERE device_id=$1
              AND measured_at >= NOW() - $2::interval
            ORDER BY measured_at ASC
            """,
            device_id,
            interval,
        )
        for row in rows:
            writer.writerow([
                row["timestamp_utc"].isoformat(),
                row["voltage_v"],
                row["current_a"],
                row["active_power_w"],
                row["power_factor"],
                row["frequency_hz"],
                row["energy_total_wh"],
                1,
                "raw",
            ])
    else:
        rows = await database.pool.fetch(
            """
            SELECT
                date_bin($3::interval, measured_at, TIMESTAMPTZ '2000-01-01 00:00:00+00') AS timestamp_utc,
                AVG(voltage_v) AS voltage_v,
                AVG(current_a) AS current_a,
                AVG(active_power_w) AS active_power_w,
                AVG(power_factor) AS power_factor,
                AVG(frequency_hz) AS frequency_hz,
                MAX(energy_total_wh) AS energy_total_wh,
                COUNT(*) AS samples
            FROM telemetry_ac
            WHERE device_id=$1
              AND measured_at >= NOW() - $2::interval
            GROUP BY 1
            ORDER BY 1 ASC
            """,
            device_id,
            interval,
            bucket,
        )
        for row in rows:
            writer.writerow([
                row["timestamp_utc"].isoformat(),
                row["voltage_v"],
                row["current_a"],
                row["active_power_w"],
                row["power_factor"],
                row["frequency_hz"],
                row["energy_total_wh"],
                row["samples"],
                bucket,
            ])

    return stream.getvalue()


async def sessions_csv(database: Database, device_id: str) -> str:
    if not database.available or database.pool is None:
        raise RuntimeError("PostgreSQL indisponible")

    rows = await database.pool.fetch(
        """
        SELECT session_id, state, started_at, ended_at, duration_s, energy_wh,
               average_power_w, max_power_w, max_current_a, average_power_factor,
               end_reason, updated_at
        FROM charging_sessions
        WHERE device_id=$1
        ORDER BY started_at DESC NULLS LAST
        """,
        device_id,
    )

    stream, writer = _csv_buffer()
    writer.writerow([
        "session_id", "state", "started_at_utc", "ended_at_utc", "duration_s",
        "energy_wh", "average_power_w", "max_power_w", "max_current_a",
        "average_power_factor", "end_reason", "updated_at_utc",
    ])
    for row in rows:
        writer.writerow([
            row["session_id"],
            row["state"],
            row["started_at"].isoformat() if row["started_at"] else "",
            row["ended_at"].isoformat() if row["ended_at"] else "",
            row["duration_s"],
            row["energy_wh"],
            row["average_power_w"],
            row["max_power_w"],
            row["max_current_a"],
            row["average_power_factor"],
            row["end_reason"] or "",
            row["updated_at"].isoformat() if row["updated_at"] else "",
        ])
    return stream.getvalue()


async def events_csv(database: Database, device_id: str) -> str:
    if not database.available or database.pool is None:
        raise RuntimeError("PostgreSQL indisponible")

    rows = await database.pool.fetch(
        """
        SELECT id, event_at, severity, code, message, source, value, threshold
        FROM events
        WHERE device_id=$1
        ORDER BY event_at DESC
        """,
        device_id,
    )

    stream, writer = _csv_buffer()
    writer.writerow(["id", "event_at_utc", "severity", "code", "message", "source", "value", "threshold"])
    for row in rows:
        writer.writerow([
            row["id"],
            row["event_at"].isoformat(),
            row["severity"],
            row["code"],
            row["message"],
            row["source"] or "",
            row["value"],
            row["threshold"],
        ])
    return stream.getvalue()
