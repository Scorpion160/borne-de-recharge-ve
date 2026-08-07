from __future__ import annotations

from typing import Any

from storage import Database

RANGE_CONFIG: dict[str, tuple[int, int]] = {
    "1m": (60, 1),
    "15m": (15 * 60, 5),
    "1h": (60 * 60, 15),
    "24h": (24 * 60 * 60, 5 * 60),
    "7d": (7 * 24 * 60 * 60, 30 * 60),
}


async def telemetry_series(
    database: Database,
    device_id: str,
    range_key: str,
) -> dict[str, Any]:
    if range_key not in RANGE_CONFIG:
        raise ValueError(f"Unsupported range: {range_key}")

    range_seconds, bucket_seconds = RANGE_CONFIG[range_key]
    if not database.available or database.pool is None:
        return {
            "range": range_key,
            "range_seconds": range_seconds,
            "bucket_seconds": bucket_seconds,
            "items": [],
        }

    rows = await database.pool.fetch(
        """
        SELECT
            to_timestamp(
                floor(extract(epoch FROM measured_at) / $3::double precision)
                * $3::double precision
            ) AS bucket_at,
            AVG(voltage_v) AS voltage_v,
            MIN(voltage_v) AS voltage_min_v,
            MAX(voltage_v) AS voltage_max_v,
            AVG(current_a) AS current_a,
            MAX(current_a) AS current_max_a,
            AVG(active_power_w) AS active_power_w,
            MAX(active_power_w) AS active_power_max_w,
            AVG(power_factor) AS power_factor,
            MIN(power_factor) AS power_factor_min,
            AVG(frequency_hz) AS frequency_hz,
            MIN(frequency_hz) AS frequency_min_hz,
            MAX(frequency_hz) AS frequency_max_hz,
            MIN(energy_total_wh) AS energy_start_wh,
            MAX(energy_total_wh) AS energy_end_wh,
            COUNT(*) AS samples
        FROM telemetry_ac
        WHERE device_id = $1
          AND measured_at >= NOW() - ($2::double precision * INTERVAL '1 second')
        GROUP BY bucket_at
        ORDER BY bucket_at ASC
        """,
        device_id,
        float(range_seconds),
        float(bucket_seconds),
    )

    return {
        "range": range_key,
        "range_seconds": range_seconds,
        "bucket_seconds": bucket_seconds,
        "items": [dict(row) for row in rows],
    }
