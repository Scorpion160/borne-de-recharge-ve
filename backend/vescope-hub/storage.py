from __future__ import annotations

import asyncio
import json
import os
from datetime import datetime, timezone
from typing import Any

import asyncpg


DATABASE_URL = os.getenv(
    "VESCOPE_DATABASE_URL",
    "postgresql://vescope:vescope@postgres:5432/vescope",
)


def parse_timestamp(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc)
    if isinstance(value, str) and value:
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


class Database:
    def __init__(self) -> None:
        self.pool: asyncpg.Pool | None = None
        self.available = False
        self.last_error: str | None = None

    async def connect(self, attempts: int = 15, delay_s: float = 2.0) -> None:
        for attempt in range(1, attempts + 1):
            try:
                self.pool = await asyncpg.create_pool(
                    DATABASE_URL,
                    min_size=1,
                    max_size=5,
                    command_timeout=10,
                )
                await self._create_schema()
                self.available = True
                self.last_error = None
                print("[DB] PostgreSQL connected", flush=True)
                return
            except Exception as exc:
                self.available = False
                self.last_error = str(exc)
                print(f"[DB] Connection attempt {attempt}/{attempts} failed: {exc}", flush=True)
                if attempt < attempts:
                    await asyncio.sleep(delay_s)

        print("[DB] Starting without persistence; real-time bridge remains active", flush=True)

    async def close(self) -> None:
        if self.pool is not None:
            await self.pool.close()
            self.pool = None
        self.available = False

    async def _create_schema(self) -> None:
        assert self.pool is not None
        statements = [
            """
            CREATE TABLE IF NOT EXISTS device_status (
                device_id TEXT PRIMARY KEY,
                online BOOLEAN,
                state TEXT,
                firmware TEXT,
                received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                raw JSONB NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS telemetry_ac (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL,
                measured_at TIMESTAMPTZ NOT NULL,
                received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                sequence BIGINT,
                quality TEXT,
                voltage_v DOUBLE PRECISION,
                current_a DOUBLE PRECISION,
                active_power_w DOUBLE PRECISION,
                apparent_power_va DOUBLE PRECISION,
                non_active_power_var_est DOUBLE PRECISION,
                power_factor DOUBLE PRECISION,
                frequency_hz DOUBLE PRECISION,
                energy_total_wh DOUBLE PRECISION,
                raw JSONB NOT NULL,
                UNIQUE(device_id, sequence)
            )
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_telemetry_ac_device_time
            ON telemetry_ac(device_id, measured_at DESC)
            """,
            """
            CREATE TABLE IF NOT EXISTS charging_sessions (
                session_id TEXT PRIMARY KEY,
                device_id TEXT NOT NULL,
                state TEXT,
                started_at TIMESTAMPTZ,
                ended_at TIMESTAMPTZ,
                duration_s BIGINT,
                energy_wh DOUBLE PRECISION,
                average_power_w DOUBLE PRECISION,
                max_power_w DOUBLE PRECISION,
                max_current_a DOUBLE PRECISION,
                average_power_factor DOUBLE PRECISION,
                end_reason TEXT,
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                raw JSONB NOT NULL
            )
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_sessions_device_started
            ON charging_sessions(device_id, started_at DESC)
            """,
            """
            CREATE TABLE IF NOT EXISTS events (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL,
                event_at TIMESTAMPTZ NOT NULL,
                received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                severity TEXT NOT NULL,
                code TEXT NOT NULL,
                message TEXT NOT NULL,
                source TEXT,
                value DOUBLE PRECISION,
                threshold DOUBLE PRECISION,
                raw JSONB NOT NULL
            )
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_events_device_time
            ON events(device_id, event_at DESC)
            """,
        ]
        async with self.pool.acquire() as conn:
            for statement in statements:
                await conn.execute(statement)

    async def save(self, device_id: str, channel: str, payload: dict[str, Any]) -> None:
        if not self.available or self.pool is None:
            return
        try:
            if channel == "status":
                await self._save_status(device_id, payload)
            elif channel == "telemetry/ac":
                await self._save_telemetry(device_id, payload)
            elif channel == "session/live":
                await self._save_session(device_id, payload, summary=False)
            elif channel == "session/summary":
                await self._save_session(device_id, payload, summary=True)
            elif channel == "alerts":
                await self.save_event(device_id, payload)
        except Exception as exc:
            self.last_error = str(exc)
            print(f"[DB] Persistence error on {device_id}/{channel}: {exc}", flush=True)

    async def _save_status(self, device_id: str, payload: dict[str, Any]) -> None:
        assert self.pool is not None
        await self.pool.execute(
            """
            INSERT INTO device_status(device_id, online, state, firmware, received_at, raw)
            VALUES($1, $2, $3, $4, NOW(), $5::jsonb)
            ON CONFLICT(device_id) DO UPDATE SET
                online = EXCLUDED.online,
                state = EXCLUDED.state,
                firmware = EXCLUDED.firmware,
                received_at = NOW(),
                raw = EXCLUDED.raw
            """,
            device_id,
            payload.get("online"),
            payload.get("state"),
            payload.get("firmware"),
            json.dumps(payload),
        )

    async def _save_telemetry(self, device_id: str, payload: dict[str, Any]) -> None:
        assert self.pool is not None
        await self.pool.execute(
            """
            INSERT INTO telemetry_ac(
                device_id, measured_at, sequence, quality, voltage_v, current_a,
                active_power_w, apparent_power_va, non_active_power_var_est,
                power_factor, frequency_hz, energy_total_wh, raw
            ) VALUES(
                $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13::jsonb
            )
            ON CONFLICT(device_id, sequence) DO NOTHING
            """,
            device_id,
            parse_timestamp(payload.get("timestamp")),
            payload.get("sequence"),
            payload.get("quality"),
            payload.get("voltage_v"),
            payload.get("current_a"),
            payload.get("active_power_w"),
            payload.get("apparent_power_va"),
            payload.get("non_active_power_var_est"),
            payload.get("power_factor"),
            payload.get("frequency_hz"),
            payload.get("energy_total_wh"),
            json.dumps(payload),
        )

    async def _save_session(self, device_id: str, payload: dict[str, Any], summary: bool) -> None:
        assert self.pool is not None
        session_id = payload.get("session_id")
        if not session_id:
            return
        ended_at = parse_timestamp(payload.get("ended_at")) if summary and payload.get("ended_at") else None
        await self.pool.execute(
            """
            INSERT INTO charging_sessions(
                session_id, device_id, state, started_at, ended_at, duration_s,
                energy_wh, average_power_w, max_power_w, max_current_a,
                average_power_factor, end_reason, updated_at, raw
            ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW(),$13::jsonb)
            ON CONFLICT(session_id) DO UPDATE SET
                state = EXCLUDED.state,
                ended_at = COALESCE(EXCLUDED.ended_at, charging_sessions.ended_at),
                duration_s = EXCLUDED.duration_s,
                energy_wh = EXCLUDED.energy_wh,
                average_power_w = EXCLUDED.average_power_w,
                max_power_w = EXCLUDED.max_power_w,
                max_current_a = EXCLUDED.max_current_a,
                average_power_factor = EXCLUDED.average_power_factor,
                end_reason = COALESCE(EXCLUDED.end_reason, charging_sessions.end_reason),
                updated_at = NOW(),
                raw = EXCLUDED.raw
            """,
            session_id,
            device_id,
            payload.get("state"),
            parse_timestamp(payload.get("started_at")) if payload.get("started_at") else None,
            ended_at,
            payload.get("duration_s"),
            payload.get("energy_wh"),
            payload.get("average_power_w"),
            payload.get("max_power_w"),
            payload.get("max_current_a"),
            payload.get("average_power_factor"),
            payload.get("end_reason") or payload.get("end_cause"),
            json.dumps(payload),
        )

    async def save_event(self, device_id: str, payload: dict[str, Any]) -> None:
        if not self.available or self.pool is None:
            return
        await self.pool.execute(
            """
            INSERT INTO events(
                device_id, event_at, severity, code, message, source, value, threshold, raw
            ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb)
            """,
            device_id,
            parse_timestamp(payload.get("timestamp")),
            payload.get("severity", "INFO"),
            payload.get("code", "EVENT"),
            payload.get("message", "Événement VE-SCOPE"),
            payload.get("source"),
            payload.get("value"),
            payload.get("threshold"),
            json.dumps(payload),
        )

    async def telemetry_history(self, device_id: str, limit: int) -> list[dict[str, Any]]:
        if not self.available or self.pool is None:
            return []
        rows = await self.pool.fetch(
            """
            SELECT measured_at, sequence, quality, voltage_v, current_a, active_power_w,
                   apparent_power_va, non_active_power_var_est, power_factor, frequency_hz,
                   energy_total_wh
            FROM telemetry_ac
            WHERE device_id=$1
            ORDER BY measured_at DESC
            LIMIT $2
            """,
            device_id,
            limit,
        )
        return [dict(row) for row in rows]

    async def sessions(self, device_id: str, limit: int) -> list[dict[str, Any]]:
        if not self.available or self.pool is None:
            return []
        rows = await self.pool.fetch(
            """
            SELECT session_id, state, started_at, ended_at, duration_s, energy_wh,
                   average_power_w, max_power_w, max_current_a, average_power_factor,
                   end_reason, updated_at
            FROM charging_sessions
            WHERE device_id=$1
            ORDER BY started_at DESC NULLS LAST
            LIMIT $2
            """,
            device_id,
            limit,
        )
        return [dict(row) for row in rows]

    async def events(self, device_id: str, limit: int) -> list[dict[str, Any]]:
        if not self.available or self.pool is None:
            return []
        rows = await self.pool.fetch(
            """
            SELECT id, event_at, severity, code, message, source, value, threshold
            FROM events
            WHERE device_id=$1
            ORDER BY event_at DESC
            LIMIT $2
            """,
            device_id,
            limit,
        )
        return [dict(row) for row in rows]
