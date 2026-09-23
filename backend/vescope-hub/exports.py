from __future__ import annotations

import csv
import io
from datetime import timedelta
from typing import Any

from storage import Database


RANGES = {
    "1h": (timedelta(hours=1), None, "raw"),
    "24h": (timedelta(hours=24), None, "raw"),
    "7d": (timedelta(days=7), timedelta(minutes=1), "1 minute"),
    "30d": (timedelta(days=30), timedelta(minutes=5), "5 minutes"),
}


def _csv_buffer() -> tuple[io.StringIO, csv.writer]:
    stream = io.StringIO()
    stream.write("\ufeff")
    return stream, csv.writer(stream, delimiter=";", lineterminator="\r\n")


async def telemetry_csv(database: Database, device_id: str, range_key: str) -> str:
    if not database.available or database.pool is None:
        raise RuntimeError("PostgreSQL indisponible")

    interval, bucket, resolution = RANGES[range_key]
    stream, writer = _csv_buffer()
    writer.writerow([
        "timestamp_utc",
        "received_at_utc",
        "sample_id",
        "boot_id",
        "sequence",
        "session_id",
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
            SELECT measured_at AS timestamp_utc, received_at AS received_at_utc,
                   sample_id, boot_id, sequence, session_id,
                   voltage_v, current_a, active_power_w,
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
                row["received_at_utc"].isoformat(),
                row["sample_id"] or "",
                row["boot_id"] if row["boot_id"] is not None else "",
                row["sequence"] if row["sequence"] is not None else "",
                row["session_id"] or "",
                row["voltage_v"],
                row["current_a"],
                row["active_power_w"],
                row["power_factor"],
                row["frequency_hz"],
                row["energy_total_wh"],
                1,
                resolution,
            ])
    else:
        rows = await database.pool.fetch(
            """
            SELECT
                date_bin($3::interval, measured_at, TIMESTAMPTZ '2000-01-01 00:00:00+00') AS timestamp_utc,
                MAX(received_at) AS received_at_utc,
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
                row["received_at_utc"].isoformat() if row["received_at_utc"] else "",
                "", "", "", "",
                row["voltage_v"],
                row["current_a"],
                row["active_power_w"],
                row["power_factor"],
                row["frequency_hz"],
                row["energy_total_wh"],
                row["samples"],
                resolution,
            ])

    return stream.getvalue()


async def trusted_telemetry_csv(database: Database, device_id: str, range_key: str) -> str:
    """Export scientifique brut : uniquement les mesures explicitement TRUSTED.

    Contrairement à telemetry_csv(), cet export ne fait aucun rééchantillonnage
    ni agrégation. Chaque ligne correspond donc à une mesure physique validée,
    avec ses identifiants de boot/échantillon et les métadonnées de validation.
    """
    if not database.available or database.pool is None:
        raise RuntimeError("PostgreSQL indisponible")

    interval = RANGES[range_key][0]
    stream, writer = _csv_buffer()
    writer.writerow([
        "trust_state",
        "timestamp_utc",
        "received_at_utc",
        "ingest_delay_s",
        "sample_id",
        "boot_id",
        "sequence",
        "session_id",
        "quality",
        "voltage_v",
        "current_a",
        "active_power_w",
        "apparent_power_va",
        "non_active_power_var_est",
        "power_factor",
        "frequency_hz",
        "energy_total_wh",
        "firmware",
        "validated_at_utc",
        "validation_note",
    ])

    rows = await database.pool.fetch(
        """
        SELECT
            t.measured_at AS timestamp_utc,
            t.received_at AS received_at_utc,
            EXTRACT(EPOCH FROM (t.received_at - t.measured_at)) AS ingest_delay_s,
            t.sample_id,
            t.boot_id,
            t.sequence,
            t.session_id,
            t.quality,
            t.voltage_v,
            t.current_a,
            t.active_power_w,
            t.apparent_power_va,
            t.non_active_power_var_est,
            t.power_factor,
            t.frequency_hz,
            t.energy_total_wh,
            r.firmware,
            r.validated_at,
            r.validation_note
        FROM telemetry_ac_trusted t
        JOIN telemetry_trust_registry r
          ON r.device_id = t.device_id
         AND r.boot_id = t.boot_id
         AND r.status = 'TRUSTED'
        WHERE t.device_id=$1
          AND t.measured_at >= NOW() - $2::interval
        ORDER BY t.measured_at ASC, t.boot_id ASC, t.sequence ASC
        """,
        device_id,
        interval,
    )

    for row in rows:
        writer.writerow([
            "TRUSTED",
            row["timestamp_utc"].isoformat(),
            row["received_at_utc"].isoformat(),
            float(row["ingest_delay_s"]) if row["ingest_delay_s"] is not None else "",
            row["sample_id"] or "",
            row["boot_id"] if row["boot_id"] is not None else "",
            row["sequence"] if row["sequence"] is not None else "",
            row["session_id"] or "",
            row["quality"] or "",
            row["voltage_v"],
            row["current_a"],
            row["active_power_w"],
            row["apparent_power_va"],
            row["non_active_power_var_est"],
            row["power_factor"],
            row["frequency_hz"],
            row["energy_total_wh"],
            row["firmware"] or "",
            row["validated_at"].isoformat() if row["validated_at"] else "",
            row["validation_note"] or "",
        ])

    return stream.getvalue()


async def session_telemetry_csv(database: Database, device_id: str, session_id: str) -> str:
    """Export raw AC samples for a session, including older untagged firmware data.

    Untagged samples are associated by time only when there are no samples with
    the exact session ID. The CSV records which association was used.
    """
    if not database.available or database.pool is None:
        raise RuntimeError("PostgreSQL indisponible")

    session = await database.pool.fetchrow(
        """
        SELECT started_at, ended_at FROM charging_sessions
        WHERE device_id=$1 AND session_id=$2
        """, device_id, session_id,
    )
    if session is None:
        raise LookupError("Session introuvable pour cette borne")

    columns = """
        measured_at, received_at, sample_id, boot_id, sequence, session_id,
        voltage_v, current_a, active_power_w, power_factor, frequency_hz,
        energy_total_wh
    """
    rows = await database.pool.fetch(
        f"SELECT {columns} FROM telemetry_ac "
        "WHERE device_id=$1 AND session_id=$2 ORDER BY measured_at ASC, sequence ASC",
        device_id, session_id,
    )
    association = "session_id"
    if not rows and session["started_at"] is not None:
        rows = await database.pool.fetch(
            f"SELECT {columns} FROM telemetry_ac "
            "WHERE device_id=$1 AND session_id IS NULL "
            "AND measured_at >= $2 AND measured_at <= COALESCE($3, NOW()) "
            "ORDER BY measured_at ASC, sequence ASC",
            device_id, session["started_at"], session["ended_at"],
        )
        association = "plage_horaire"

    if not rows:
        raise ValueError("Aucune mesure AC conservée pour cette session")

    stream, writer = _csv_buffer()
    writer.writerow([
        "timestamp_utc", "received_at_utc", "sample_id", "boot_id",
        "sequence", "session_id", "voltage_v", "current_a", "active_power_w",
        "power_factor", "frequency_hz", "energy_total_wh", "association",
    ])
    for row in rows:
        writer.writerow([
            row["measured_at"].isoformat(), row["received_at"].isoformat(),
            row["sample_id"] or "", row["boot_id"] if row["boot_id"] is not None else "",
            row["sequence"] if row["sequence"] is not None else "",
            row["session_id"] or "", row["voltage_v"], row["current_a"],
            row["active_power_w"], row["power_factor"], row["frequency_hz"],
            row["energy_total_wh"], association,
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
