import {
  pushHubAlert,
  setHubConnected,
  setHubSession,
  setHubStationState,
  setHubTelemetry,
} from './dataBridge';
import type { AcTelemetry, AlertItem, LiveSession, StationState } from './types';

function buildWebSocketUrl(): string {
  const configured = import.meta.env.VITE_VESCOPE_HUB_WS as string | undefined;
  if (configured) return configured;

  const deviceId = (import.meta.env.VITE_VESCOPE_DEVICE_ID as string | undefined) ?? 'borne-01';
  const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
  const isDevPort = window.location.port === '5173' || window.location.port === '5174';
  const authority = isDevPort ? `${window.location.hostname}:8003` : window.location.host;
  return `${protocol}://${authority}/api/v1/ws/devices/${deviceId}`;
}

function applySnapshot(snapshot: Record<string, { payload?: unknown }> | undefined): void {
  if (!snapshot) return;

  const telemetry = snapshot['telemetry/ac']?.payload as AcTelemetry | undefined;
  const session = snapshot['session/live']?.payload as LiveSession | undefined;
  const status = snapshot.status?.payload as { state?: StationState } | undefined;

  if (telemetry) setHubTelemetry(telemetry);
  if (session) setHubSession(session);
  if (status?.state) setHubStationState(status.state);
}

function normalizeAlert(data: Record<string, unknown>): AlertItem {
  const timestamp = String(data.timestamp ?? new Date().toISOString());
  const code = String(data.code ?? 'HUB_EVENT');
  return {
    id: String(data.id ?? `${code}-${timestamp}`),
    timestamp,
    severity: (data.severity ?? 'INFO') as AlertItem['severity'],
    code,
    message: String(data.message ?? 'Événement reçu de VE-SCOPE Hub.'),
  };
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

        if (message.event === 'connected') {
          applySnapshot(message.snapshot);
          return;
        }

        if (message.event === 'telemetry_ac' && message.data) {
          setHubTelemetry(message.data as AcTelemetry);
          return;
        }

        if (message.event === 'session_live' && message.data) {
          setHubSession(message.data as LiveSession);
          return;
        }

        if (message.event === 'status_update' && message.data?.state) {
          setHubStationState(message.data.state as StationState);
          return;
        }

        if (message.event === 'alert' && message.data) {
          pushHubAlert(normalizeAlert(message.data as Record<string, unknown>));
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
