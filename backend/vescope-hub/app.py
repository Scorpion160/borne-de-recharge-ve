from __future__ import annotations

import asyncio
import json
import os
from collections import defaultdict
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any

import paho.mqtt.client as mqtt
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

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


latest: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)
clients: dict[str, set[WebSocket]] = defaultdict(set)


async def broadcast(device_id: str, message: dict[str, Any]) -> None:
    stale: list[WebSocket] = []
    for socket in list(clients.get(device_id, set())):
        try:
            await socket.send_json(message)
        except Exception:
            stale.append(socket)
    for socket in stale:
        clients[device_id].discard(socket)


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

    def start(self, loop: asyncio.AbstractEventLoop) -> None:
        self.loop = loop
        self.client.connect_async(MQTT_HOST, MQTT_PORT, keepalive=60)
        self.client.loop_start()

    def stop(self) -> None:
        self.client.disconnect()
        self.client.loop_stop()

    def on_connect(self, client, userdata, flags, reason_code, properties) -> None:
        self.connected = not getattr(reason_code, "is_failure", False)
        if not self.connected:
            return
        for suffix, (_, qos) in CHANNELS.items():
            client.subscribe(f"{TOPIC_PREFIX}/+/{suffix}", qos=qos)

    def on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties) -> None:
        self.connected = False

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
        asyncio.run_coroutine_threadsafe(
            self.handle(device_id, channel, payload),
            self.loop,
        )

    async def handle(self, device_id: str, channel: str, payload: dict[str, Any]) -> None:
        received_at = now_iso()
        latest[device_id][channel] = {"received_at": received_at, "payload": payload}
        event_name = CHANNELS[channel][0]
        await broadcast(
            device_id,
            {
                "event": event_name,
                "device_id": device_id,
                "received_at": received_at,
                "data": payload,
            },
        )


bridge = MqttBridge()


@asynccontextmanager
async def lifespan(app: FastAPI):
    bridge.start(asyncio.get_running_loop())
    try:
        yield
    finally:
        bridge.stop()


app = FastAPI(title="VE-SCOPE Hub", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_methods=["GET", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": "vescope-hub",
        "mqtt_connected": bridge.connected,
        "mqtt_last_message_at": bridge.last_message_at,
        "timestamp": now_iso(),
    }


@app.get("/api/v1/devices")
async def devices() -> dict[str, Any]:
    return {"devices": sorted(latest.keys())}


@app.get("/api/v1/devices/{device_id}/latest")
async def device_latest(device_id: str) -> dict[str, Any]:
    return {"device_id": device_id, "channels": latest.get(device_id, {})}


@app.websocket("/api/v1/ws/devices/{device_id}")
async def device_ws(websocket: WebSocket, device_id: str) -> None:
    await websocket.accept()
    clients[device_id].add(websocket)
    await websocket.send_json(
        {
            "event": "connected",
            "device_id": device_id,
            "timestamp": now_iso(),
            "snapshot": latest.get(device_id, {}),
        }
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
