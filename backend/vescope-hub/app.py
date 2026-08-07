from __future__ import annotations

import asyncio
import json
import os
import time
from collections import defaultdict
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any

import paho.mqtt.client as mqtt
from fastapi import FastAPI, HTTPException, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from alarms import AlarmEngine
from analytics import telemetry_series
from storage import Database

MQTT_HOST = os.getenv("VESCOPE_MQTT_HOST", "mqtt")
MQTT_PORT = int(os.getenv("VESCOPE_MQTT_PORT", "1883"))
TOPIC_PREFIX = os.getenv("VESCOPE_MQTT_TOPIC_PREFIX", "vescope").strip("/")

CHANNELS = {
    "status": ("status_update", 1),
    "telemetry/ac": ("telemetry_ac", 0),
    "session/live": ("session_live", 0),
    "session/summary": ("session_summary", 1),
    "alerts": ("alert", 1),
    "diagnostics": ("diagnostics", 0),
    "bms": ("bms", 0),
    "charger": ("charger", 0),
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class Utf8JsonResponse(JSONResponse):
    media_type = "application/json; charset=utf-8"


class AlarmSettingsPayload(BaseModel):
    low_voltage_v: float = Field(ge=100, le=299)
    high_voltage_v: float = Field(ge=101, le=300)
    low_power_factor: float = Field(ge=0.1, le=1.0)
    low_frequency_hz: float = Field(ge=40, le=69)
    high_frequency_hz: float = Field(ge=41, le=70)
    stale_after_s: float = Field(ge=2, le=300)


latest: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)
clients: dict[str, set[WebSocket]] = defaultdict(set)
database = Database()
alarm_engine = AlarmEngine()
settings_loaded: set[str] = set()


async def broadcast(device_id: str, message: dict[str, Any]) -> None:
    stale: list[WebSocket] = []
    for socket in list(clients.get(device_id, set())):
        try:
            await socket.send_json(message)
        except Exception:
            stale.append(socket)
    for socket in stale:
        clients[device_id].discard(socket)


async def emit_alert(device_id: str, payload: dict[str, Any]) -> None:
    received_at = now_iso()
    latest[device_id]["alerts"] = {"received_at": received_at, "payload": payload}
    await database.save_event(device_id, payload)
    await broadcast(
        device_id,
        {"event": "alert", "device_id": device_id, "received_at": received_at, "data": payload},
    )


async def ensure_alarm_settings(device_id: str) -> None:
    if device_id in settings_loaded:
        return
    stored = await database.get_settings(device_id)
    alarm_engine.configure(device_id, stored)
    settings_loaded.add(device_id)


class MqttBridge:
    def __init__(self) -> None:
        self.connected = False
        self.last_message_at: str | None = None
        self.loop: asyncio.AbstractEventLoop | None = None
        self.client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2,
            client_id="vescope_hub",
            protocol=mqtt.MQTTv311,
        )
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.client.on_message = self.on_message
        self.last_telemetry_monotonic: dict[str, float] = {}

    def start(self, loop: asyncio.AbstractEventLoop) -> None:
        self.loop = loop
        self.client.connect_async(MQTT_HOST, MQTT_PORT, keepalive=60)
        self.client.loop_start()
        print(f"[MQTT] Connecting to {MQTT_HOST}:{MQTT_PORT}", flush=True)

    def stop(self) -> None:
        self.client.disconnect()
        self.client.loop_stop()

    def on_connect(self, client, userdata, flags, reason_code, properties) -> None:
        self.connected = not getattr(reason_code, "is_failure", False)
        print(f"[MQTT] Connected={self.connected} reason={reason_code}", flush=True)
        if not self.connected:
            return
        for suffix, (_, qos) in CHANNELS.items():
            topic = f"{TOPIC_PREFIX}/+/{suffix}"
            client.subscribe(topic, qos=qos)
            print(f"[MQTT] Subscribe {topic} QoS={qos}", flush=True)

    def on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties) -> None:
        self.connected = False
        print(f"[MQTT] Disconnected reason={reason_code}", flush=True)

    def on_message(self, client, userdata, msg) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
        except Exception:
            return
        if not isinstance(payload, dict) or payload.get("schema") != 1:
            return
        parts = msg.topic.split("/")
        if len(parts) < 3 or parts[0] != TOPIC_PREFIX:
            return
        device_id = parts[1]
        channel = "/".join(parts[2:])
        if channel not in CHANNELS or not self.loop:
            return
        if payload.get("device_id") not in (None, device_id):
            return

        self.last_message_at = now_iso()
        if channel == "telemetry/ac":
            self.last_telemetry_monotonic[device_id] = time.monotonic()

        asyncio.run_coroutine_threadsafe(self.handle(device_id, channel, payload), self.loop)

    async def handle(self, device_id: str, channel: str, payload: dict[str, Any]) -> None:
        received_at = now_iso()
        latest[device_id][channel] = {"received_at": received_at, "payload": payload}
        await database.save(device_id, channel, payload)

        event_name = CHANNELS[channel][0]
        await broadcast(
            device_id,
            {"event": event_name, "device_id": device_id, "received_at": received_at, "data": payload},
        )

        if channel == "telemetry/ac":
            await ensure_alarm_settings(device_id)
            for alert in alarm_engine.evaluate_telemetry(device_id, payload):
                await emit_alert(device_id, alert)


bridge = MqttBridge()


async def stale_monitor() -> None:
    while True:
        now = time.monotonic()
        for device_id, last_seen in list(bridge.last_telemetry_monotonic.items()):
            await ensure_alarm_settings(device_id)
            age_s = max(0.0, now - last_seen)
            for alert in alarm_engine.evaluate_staleness(device_id, age_s):
                await emit_alert(device_id, alert)
        await asyncio.sleep(1.0)


async def database_reconnect_monitor() -> None:
    while True:
        if not database.available:
            await database.connect(attempts=1)
        await asyncio.sleep(10.0)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect(attempts=3, delay_s=1.0)
    bridge.start(asyncio.get_running_loop())
    stale_task = asyncio.create_task(stale_monitor())
    db_task = asyncio.create_task(database_reconnect_monitor())
    try:
        yield
    finally:
        stale_task.cancel()
        db_task.cancel()
        bridge.stop()
        await database.close()


app = FastAPI(
    title="VE-SCOPE Hub",
    version="0.4.0",
    lifespan=lifespan,
    default_response_class=Utf8JsonResponse,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "PUT", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": "vescope-hub",
        "version": "0.4.0",
        "mqtt_connected": bridge.connected,
        "mqtt_last_message_at": bridge.last_message_at,
        "database_connected": database.available,
        "database_last_error": database.last_error,
        "timestamp": now_iso(),
    }


@app.get("/api/v1/devices")
async def devices() -> dict[str, Any]:
    return {"devices": sorted(latest.keys())}


@app.get("/api/v1/devices/{device_id}/latest")
async def device_latest(device_id: str) -> dict[str, Any]:
    return {"device_id": device_id, "channels": latest.get(device_id, {})}


@app.get("/api/v1/devices/{device_id}/telemetry")
async def telemetry_history(device_id: str, limit: int = Query(default=300, ge=1, le=5000)) -> dict[str, Any]:
    return {"device_id": device_id, "items": await database.telemetry_history(device_id, limit)}


@app.get("/api/v1/devices/{device_id}/telemetry/series")
async def telemetry_history_series(
    device_id: str,
    range_key: str = Query(default="15m", alias="range", pattern="^(1m|15m|1h|24h|7d)$"),
) -> dict[str, Any]:
    series = await telemetry_series(database, device_id, range_key)
    return {"device_id": device_id, **series}


@app.get("/api/v1/devices/{device_id}/sessions")
async def session_history(device_id: str, limit: int = Query(default=50, ge=1, le=500)) -> dict[str, Any]:
    return {"device_id": device_id, "items": await database.sessions(device_id, limit)}


@app.get("/api/v1/devices/{device_id}/events")
async def event_history(device_id: str, limit: int = Query(default=100, ge=1, le=1000)) -> dict[str, Any]:
    return {"device_id": device_id, "items": await database.events(device_id, limit)}


@app.get("/api/v1/devices/{device_id}/settings")
async def get_settings(device_id: str) -> dict[str, Any]:
    stored = await database.get_settings(device_id)
    settings = alarm_engine.configure(device_id, stored)
    settings_loaded.add(device_id)
    return {
        "device_id": device_id,
        "alarm_thresholds": settings.as_dict(),
        "persisted": stored is not None,
    }


@app.put("/api/v1/devices/{device_id}/settings")
async def put_settings(device_id: str, payload: AlarmSettingsPayload) -> dict[str, Any]:
    try:
        settings = alarm_engine.configure(device_id, payload.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    try:
        stored = await database.save_settings(device_id, settings.as_dict())
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    settings_loaded.add(device_id)
    await emit_alert(
        device_id,
        {
            "schema": 1,
            "device_id": device_id,
            "timestamp": now_iso(),
            "severity": "INFO",
            "code": "ALARM_SETTINGS_UPDATED",
            "message": "Seuils de supervision mis à jour",
            "source": "vescope_supervisor",
            "value": None,
            "threshold": None,
            "generated_by": "vescope_hub",
        },
    )
    return {"device_id": device_id, "alarm_thresholds": settings.as_dict(), "updated_at": stored["updated_at"]}


@app.websocket("/api/v1/ws/devices/{device_id}")
async def device_ws(websocket: WebSocket, device_id: str) -> None:
    await websocket.accept()
    clients[device_id].add(websocket)
    await websocket.send_json(
        {"event": "connected", "device_id": device_id, "timestamp": now_iso(), "snapshot": latest.get(device_id, {})}
    )
    try:
        while True:
            message = await websocket.receive_text()
            if message == "ping":
                await websocket.send_json({"event": "pong", "timestamp": now_iso()})
    except WebSocketDisconnect:
        pass
    finally:
        clients[device_id].discard(websocket)
