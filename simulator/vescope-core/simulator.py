#!/usr/bin/env python3
"""VE-SCOPE Core simulator.

Publishes realistic AC telemetry using the MQTT contract defined in
`docs/protocols/mqtt-v1.md`. It can also run in stdout-only mode so the
frontend/backend can be developed before a broker is available.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import signal
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

import paho.mqtt.client as mqtt


SCHEMA = 1


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


@dataclass
class Session:
    session_id: str
    started_monotonic: float
    started_at: str
    energy_start_wh: float
    samples: int = 0
    sum_power_w: float = 0.0
    sum_pf: float = 0.0
    max_power_w: float = 0.0
    max_current_a: float = 0.0

    def update(self, power_w: float, current_a: float, power_factor: float) -> None:
        self.samples += 1
        self.sum_power_w += power_w
        self.sum_pf += power_factor
        self.max_power_w = max(self.max_power_w, power_w)
        self.max_current_a = max(self.max_current_a, current_a)

    def payload(self, device_id: str, energy_total_wh: float) -> dict:
        duration_s = int(time.monotonic() - self.started_monotonic)
        return {
            "schema": SCHEMA,
            "device_id": device_id,
            "session_id": self.session_id,
            "state": "CHARGING",
            "started_at": self.started_at,
            "duration_s": duration_s,
            "energy_wh": max(0.0, energy_total_wh - self.energy_start_wh),
            "average_power_w": self.sum_power_w / self.samples if self.samples else 0.0,
            "max_power_w": self.max_power_w,
            "max_current_a": self.max_current_a,
            "average_power_factor": self.sum_pf / self.samples if self.samples else 0.0,
        }


@dataclass
class SimulatorState:
    device_id: str
    interval_s: float
    sequence: int = 0
    energy_total_wh: float = 12500.0
    session: Optional[Session] = None
    running: bool = True
    phase: float = 0.0
    charging: bool = True
    last_monotonic: float = field(default_factory=time.monotonic)

    def next_sample(self) -> dict:
        now = time.monotonic()
        dt_s = max(now - self.last_monotonic, 0.0)
        self.last_monotonic = now
        self.sequence += 1
        self.phase += self.interval_s / 18.0

        voltage_v = 230.0 + 1.7 * math.sin(self.phase / 2.0) + random.uniform(-0.45, 0.45)
        frequency_hz = 50.0 + random.uniform(-0.025, 0.025)

        if self.charging:
            current_a = 9.6 + 0.25 * math.sin(self.phase) + random.uniform(-0.10, 0.10)
            power_factor = min(0.995, max(0.90, 0.972 + random.uniform(-0.008, 0.008)))
        else:
            current_a = max(0.0, random.uniform(0.0, 0.03))
            power_factor = 0.0 if current_a < 0.01 else 0.55

        apparent_power_va = voltage_v * current_a
        active_power_w = apparent_power_va * power_factor
        non_active_q = math.sqrt(max(apparent_power_va**2 - active_power_w**2, 0.0))

        self.energy_total_wh += active_power_w * dt_s / 3600.0

        return {
            "schema": SCHEMA,
            "device_id": self.device_id,
            "timestamp": iso_now(),
            "sequence": self.sequence,
            "quality": "GOOD",
            "voltage_v": round(voltage_v, 2),
            "current_a": round(current_a, 3),
            "active_power_w": round(active_power_w, 1),
            "apparent_power_va": round(apparent_power_va, 1),
            "non_active_power_var_est": round(non_active_q, 1),
            "power_factor": round(power_factor, 3),
            "frequency_hz": round(frequency_hz, 3),
            "energy_total_wh": round(self.energy_total_wh, 2),
        }


def make_session_id(device_id: str) -> str:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    short_id = device_id.upper().replace("BORNE-", "VE")
    return f"{short_id}-{stamp}"


def json_dump(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Simulateur VE-SCOPE Core")
    p.add_argument("--device-id", default="borne-01")
    p.add_argument("--broker", default="localhost")
    p.add_argument("--port", type=int, default=1883)
    p.add_argument("--username")
    p.add_argument("--password")
    p.add_argument("--interval", type=float, default=1.0)
    p.add_argument("--stdout-only", action="store_true")
    p.add_argument("--idle", action="store_true", help="Démarrer sans charge")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    state = SimulatorState(device_id=args.device_id, interval_s=max(args.interval, 0.2))
    state.charging = not args.idle

    client: Optional[mqtt.Client] = None
    prefix = f"vescope/{state.device_id}"

    if not args.stdout_only:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"sim-{state.device_id}")
        if args.username:
            client.username_pw_set(args.username, args.password)
        client.will_set(
            f"{prefix}/status",
            json_dump({
                "schema": SCHEMA,
                "device_id": state.device_id,
                "online": False,
                "state": "OFFLINE",
            }),
            qos=1,
            retain=True,
        )
        client.connect(args.broker, args.port, keepalive=30)
        client.loop_start()
        client.publish(
            f"{prefix}/status",
            json_dump({
                "schema": SCHEMA,
                "device_id": state.device_id,
                "online": True,
                "state": "CHARGING" if state.charging else "IDLE",
                "firmware": "simulator-0.1.0",
            }),
            qos=1,
            retain=True,
        )

    def stop_handler(*_: object) -> None:
        state.running = False

    signal.signal(signal.SIGINT, stop_handler)
    signal.signal(signal.SIGTERM, stop_handler)

    print(f"VE-SCOPE simulator started for {state.device_id}", file=sys.stderr)

    try:
        while state.running:
            telemetry = state.next_sample()

            if state.charging and state.session is None:
                state.session = Session(
                    session_id=make_session_id(state.device_id),
                    started_monotonic=time.monotonic(),
                    started_at=iso_now(),
                    energy_start_wh=state.energy_total_wh,
                )

            if state.session is not None:
                state.session.update(
                    telemetry["active_power_w"],
                    telemetry["current_a"],
                    telemetry["power_factor"],
                )

            if args.stdout_only:
                print(json_dump(telemetry), flush=True)
            else:
                assert client is not None
                client.publish(f"{prefix}/telemetry/ac", json_dump(telemetry), qos=0)

            if state.session is not None:
                live = state.session.payload(state.device_id, state.energy_total_wh)
                if args.stdout_only:
                    print(json_dump({"type": "session", **live}), flush=True)
                else:
                    assert client is not None
                    client.publish(f"{prefix}/session/live", json_dump(live), qos=0)

            time.sleep(state.interval_s)
    finally:
        if client is not None:
            client.publish(
                f"{prefix}/status",
                json_dump({
                    "schema": SCHEMA,
                    "device_id": state.device_id,
                    "online": False,
                    "state": "OFFLINE",
                }),
                qos=1,
                retain=True,
            )
            client.loop_stop()
            client.disconnect()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
