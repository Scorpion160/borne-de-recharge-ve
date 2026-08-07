import { setHubConnected, setHubTelemetry } from './dataBridge';
import type { AcTelemetry } from './types';

function buildWebSocketUrl(): string {
  const configured = import.meta.env.VITE_VESCOPE_HUB_WS as string | undefined;
  if (configured) return configured;

  const deviceId = (import.meta.env.VITE_VESCOPE_DEVICE_ID as string | undefined) ?? 'borne-01';
  const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
  return `${protocol}://${window.location.hostname}:8003/api/v1/ws/devices/${deviceId}`;
}

export function startHubClient(): () => void {
  const mode = ((import.meta.env.VITE_VESCOPE_DATA_SOURCE as string | undefined) ?? 'auto').toLowerCase();
  if (mode === 'simulation') return () => undefined;

  let socket: WebSocket | null = null;
  let stopped = false;
  let retryMs = 1000;
  let retryTimer: number | undefined;

  const connect = () => {
    if (stopped) return;

    socket = new WebSocket(buildWebSocketUrl());

    socket.onopen = () => {
      retryMs = 1000;
      setHubConnected(true);
    };

    socket.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);

        if (message.event === 'telemetry_ac' && message.data) {
          setHubTelemetry(message.data as AcTelemetry);
          return;
        }

        if (message.event === 'connected' && message.snapshot?.['telemetry/ac']?.payload) {
          setHubTelemetry(message.snapshot['telemetry/ac'].payload as AcTelemetry);
        }
      } catch (error) {
        console.warn('[VE-SCOPE Hub] Message WebSocket invalide', error);
      }
    };

    socket.onerror = () => {
      socket?.close();
    };

    socket.onclose = () => {
      setHubConnected(false);
      if (stopped) return;
      retryTimer = window.setTimeout(connect, retryMs);
      retryMs = Math.min(retryMs * 2, 15000);
    };
  };

  connect();

  return () => {
    stopped = true;
    setHubConnected(false);
    if (retryTimer) window.clearTimeout(retryTimer);
    socket?.close();
  };
}
