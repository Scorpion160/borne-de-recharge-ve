import type { AlertItem, StationState } from './types';

export interface StoredSession {
  session_id: string;
  state: StationState;
  started_at: string | null;
  ended_at: string | null;
  duration_s: number | null;
  energy_wh: number | null;
  average_power_w: number | null;
  max_power_w: number | null;
  max_current_a: number | null;
  average_power_factor: number | null;
  end_reason: string | null;
  updated_at: string;
}

export interface HubHealth {
  ok: boolean;
  service: string;
  version?: string;
  mqtt_connected: boolean;
  mqtt_last_message_at?: string | null;
  database_connected: boolean;
  database_last_error?: string | null;
  timestamp: string;
}

interface StoredEventResponse {
  id: number;
  event_at: string;
  severity: AlertItem['severity'];
  code: string;
  message: string;
  source?: string | null;
  value?: number | null;
  threshold?: number | null;
}

function apiBase(): string {
  const configured = import.meta.env.VITE_VESCOPE_HUB_HTTP as string | undefined;
  if (configured) return configured.replace(/\/$/, '');
  return `${window.location.protocol}//${window.location.hostname}:8003`;
}

function deviceId(): string {
  return (import.meta.env.VITE_VESCOPE_DEVICE_ID as string | undefined) ?? 'borne-01';
}

async function getJson<T>(path: string): Promise<T | null> {
  try {
    const response = await fetch(`${apiBase()}${path}`, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) return null;
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

export async function fetchHubHealth(): Promise<HubHealth | null> {
  return getJson<HubHealth>('/health');
}

export async function fetchStoredSessions(limit = 50): Promise<StoredSession[]> {
  const result = await getJson<{ items: StoredSession[] }>(
    `/api/v1/devices/${encodeURIComponent(deviceId())}/sessions?limit=${limit}`,
  );
  return result?.items ?? [];
}

export async function fetchStoredEvents(limit = 100): Promise<AlertItem[]> {
  const result = await getJson<{ items: StoredEventResponse[] }>(
    `/api/v1/devices/${encodeURIComponent(deviceId())}/events?limit=${limit}`,
  );
  return (result?.items ?? []).map((item) => ({
    id: `db-${item.id}`,
    timestamp: item.event_at,
    severity: item.severity,
    code: item.code,
    message: item.message,
  }));
}
