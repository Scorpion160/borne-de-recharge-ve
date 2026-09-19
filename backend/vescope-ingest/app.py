from __future__ import annotations

import hmac
import os
from typing import Any

import httpx
from fastapi import FastAPI, Header, HTTPException

INGEST_TOKEN = os.getenv("VESCOPE_INGEST_TOKEN", "")
HUB_URL = os.getenv("VESCOPE_HUB_URL", "http://hub:8000").rstrip("/")
INTERNAL_TOKEN = os.getenv("VESCOPE_INTERNAL_INGEST_TOKEN", "")

SUPPORTED_CHANNELS = {
    "status",
    "telemetry/ac",
    "session/live",
    "session/summary",
    "diagnostics",
    "alerts",
    "bms",
    "charger",
}

app = FastAPI(title="VE-SCOPE HTTPS Ingest", version="0.2.1")


def require_token(authorization: str | None) -> None:
    if not INGEST_TOKEN:
        raise HTTPException(status_code=503, detail="Ingest token not configured")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Bearer token required")
    provided = authorization[7:]
    if not hmac.compare_digest(provided, INGEST_TOKEN):
        raise HTTPException(status_code=403, detail="Invalid device token")


@app.get("/health")
async def health() -> dict[str, Any]:
    hub_ok = False
    database_connected = False
    try:
        async with httpx.AsyncClient(timeout=2.5) as client:
            response = await client.get(f"{HUB_URL}/health")
            if response.status_code == 200:
                payload = response.json()
                hub_ok = bool(payload.get("ok"))
                database_connected = bool(payload.get("database_connected"))
    except Exception:
        pass

    return {
        "ok": hub_ok and database_connected,
        "service": "vescope-ingest",
        "version": "0.2.1",
        "hub_reachable": hub_ok,
        "database_connected": database_connected,
    }


@app.post("/api/v1/ingest/{device_id}/{channel:path}")
async def ingest(
    device_id: str,
    channel: str,
    payload: dict[str, Any],
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    require_token(authorization)

    if channel not in SUPPORTED_CHANNELS:
        raise HTTPException(status_code=404, detail="Unsupported channel")
    if payload.get("schema") != 1:
        raise HTTPException(status_code=422, detail="schema must be 1")
    if payload.get("device_id") not in (None, device_id):
        raise HTTPException(status_code=422, detail="device_id mismatch")
    if not INTERNAL_TOKEN:
        raise HTTPException(status_code=503, detail="Internal ingest token not configured")

    payload["device_id"] = device_id
    url = f"{HUB_URL}/internal/v1/ingest/{device_id}/{channel}"
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.post(
                url,
                json=payload,
                # FastAPI convertit x_vescope_internal_token en en-tête
                # HTTP `X-VESCOPE-Internal-Token` (underscores -> tirets).
                headers={"X-VESCOPE-Internal-Token": INTERNAL_TOKEN},
            )
    except httpx.RequestError as exc:
        raise HTTPException(status_code=503, detail=f"Hub unavailable: {exc}") from exc

    if response.status_code < 200 or response.status_code >= 300:
        detail = response.text[:500]
        raise HTTPException(status_code=503, detail=f"Hub persistence failed: {detail}")

    # Un 2xx public signifie désormais : donnée déjà persistée par le Hub.
    return {
        "ok": True,
        "transport": "https",
        "persisted": True,
        "device_id": device_id,
        "channel": channel,
    }
