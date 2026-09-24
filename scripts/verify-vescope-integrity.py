#!/usr/bin/env python3
"""Check that a real device's samples and completed sessions reach PostgreSQL.

Run inside the Hub container: docker exec -i vescope_hub python - < this-file
The check is read-only; it never repairs or synthesizes measurements.
"""

import asyncio
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from urllib.request import urlopen

import asyncpg


def age_seconds(value, now):
    return (now - value).total_seconds() if value is not None else float("inf")


def firmware_current(value):
    match = re.search(r"(?:^|\D)(\d+)\.(\d+)\.(\d+)(?:\D|$)", value or "")
    return bool(match and tuple(map(int, match.groups())) >= (0, 2, 13))


async def check():
    device = os.getenv("VESCOPE_CHECK_DEVICE", "borne-01")
    now = datetime.now(timezone.utc)
    errors = []

    try:
        with urlopen(f"http://127.0.0.1:8000/api/v1/devices/{device}/latest", timeout=5) as response:
            channels = json.load(response).get("channels", {})
    except Exception as exc:
        print(f"ÉCHEC Hub inaccessible : {exc}")
        return 1

    status = channels.get("status", {}).get("payload", {})
    diagnostics = channels.get("diagnostics", {}).get("payload", {})
    firmware = status.get("firmware") or diagnostics.get("firmware")
    print(f"Borne {device} ; firmware {firmware or 'inconnu'}")
    if not firmware_current(firmware):
        errors.append("firmware 0.2.13-field ou plus récent non confirmé")

    if not status or age_seconds(datetime.fromisoformat(channels["status"]["received_at"].replace("Z", "+00:00")), now) > 120:
        errors.append("statut de la borne absent ou vieux de plus de 2 minutes")
    if not diagnostics or age_seconds(datetime.fromisoformat(channels["diagnostics"]["received_at"].replace("Z", "+00:00")), now) > 120:
        errors.append("diagnostic de la borne absent ou vieux de plus de 2 minutes")
    if diagnostics.get("durable_store_ok") is not True:
        errors.append("file persistante de l'ESP32 non confirmée")
    if diagnostics.get("durable_queue_error") is True:
        errors.append("erreur signalée par la file persistante")
    pending = diagnostics.get("durable_pending_telemetry")
    print(f"File en attente : {pending if pending is not None else 'inconnue'} mesures")

    url = os.getenv("VESCOPE_DATABASE_URL")
    if not url:
        errors.append("VESCOPE_DATABASE_URL absent")
    else:
        db = await asyncpg.connect(url, timeout=5)
        try:
            latest = await db.fetchrow(
                "SELECT max(received_at) AS received_at, count(*) FILTER "
                "(WHERE received_at >= $2) AS recent FROM telemetry_ac WHERE device_id=$1",
                device, now - timedelta(minutes=2),
            )
            print(f"Mesures PostgreSQL depuis 2 min : {latest['recent']}")
            if latest["recent"] == 0:
                errors.append("aucune mesure AC enregistrée dans PostgreSQL depuis 2 minutes")

            sessions = await db.fetch(
                """SELECT s.session_id, s.started_at, s.ended_at,
                    (SELECT count(*) FROM telemetry_ac t
                     WHERE t.device_id=s.device_id
                       AND (t.session_id=s.session_id OR
                            (t.session_id IS NULL AND t.measured_at >= s.started_at
                             AND t.measured_at <= COALESCE(s.ended_at, $2)))) AS samples
                   FROM charging_sessions s
                   WHERE s.device_id=$1 AND s.started_at >= $3
                   ORDER BY s.started_at DESC LIMIT 20""",
                device, now, now - timedelta(hours=24),
            )
            for row in sessions:
                print(f"Session {row['session_id']} : {row['samples']} mesures en base")
                if row["samples"] == 0 and age_seconds(row["started_at"], now) > 120:
                    errors.append(f"session {row['session_id']} sans mesure AC")
        finally:
            await db.close()

    if errors:
        for error in errors:
            print(f"ÉCHEC : {error}")
        return 1
    print("OK : firmware, file ESP32 et mesures PostgreSQL vérifiés")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(asyncio.run(check()))
    except Exception as exc:
        print(f"ÉCHEC : vérification interrompue : {exc}")
        sys.exit(1)
