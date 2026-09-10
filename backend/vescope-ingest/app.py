from __future__ import annotations

import hmac
import os
from typing import Any

import paho.mqtt.client as mqtt
from fastapi import FastAPI, Header, HTTPException

MQTT_HOST = os.getenv("VESCOPE_MQTT_HOST", "mqtt")
MQTT_PORT = int(os.getenv("VESCOPE_MQTT_PORT", "1883"))
TOPIC_PREFIX = os.getenv("VESCOPE_MQTT_TOPIC_PREFIX", "vescope").strip("/")
INGEST_TOKEN = os.getenv("VESCOPE_INGEST_TOKEN", "")

CHANNEL_QOS = {
    "status": 1,
    "telemetry/ac": 0,
    "session/live": 0,
    "session/summary": 1,
    "diagnostics": 0,
    "alerts": 1,
    "bms": 0,
    "charger": 0,
}

app = FastAPI(title="VE-SCOPE HTTPS Ingest", version="0.1.0")
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="vescope_https_ingest")
connected = False


def on_connect(client_, userdata, flags, reason_code, properties) -> None:
    global connected
    connected = not getattr(reason_code, "is_failure", False)


def on_disconnect(client_, userdata, disconnect_flags, reason_code, properties) -> None:
    global connected
    connected = False


client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.connect_async(MQTT_HOST, MQTT_PORT, keepalive=60)
client.loop_start()


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
    return {
        "ok": True,
        "service": "vescope-ingest",
        "mqtt_connected": connected,
    }


@app.post("/api/v1/ingest/{device_id}/{channel:path}")
async def ingest(
    device_id: str,
    channel: str,
    payload: dict[str, Any],
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    require_token(authorization)

    if channel not in CHANNEL_QOS:
        raise HTTPException(status_code=404, detail="Unsupported channel")
    if payload.get("schema") != 1:
        raise HTTPException(status_code=422, detail="schema must be 1")
    if payload.get("device_id") not in (None, device_id):
        raise HTTPException(status_code=422, detail="device_id mismatch")
    if not connected:
        raise HTTPException(status_code=503, detail="Internal MQTT unavailable")

    payload["device_id"] = device_id
    topic = f"{TOPIC_PREFIX}/{device_id}/{channel}"
    qos = CHANNEL_QOS[channel]
    retain = channel == "status"

    info = client.publish(topic, payload=str_json(payload), qos=qos, retain=retain)
    if info.rc != mqtt.MQTT_ERR_SUCCESS:
        raise HTTPException(status_code=503, detail=f"MQTT publish failed rc={info.rc}")

    return {"ok": True, "transport": "https", "topic": topic}


def str_json(payload: dict[str, Any]) -> str:
    import json

    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
