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

export interface AlarmThresholds {
  low_voltage_v: number;
  high_voltage_v: number;
  low_power_factor: number;
  low_frequency_hz: number;
  high_frequency_hz: number;
  stale_after_s: number;
}

export interface DeviceSettingsResponse {
  device_id: string;
  alarm_thresholds: AlarmThresholds;
  persisted?: boolean;
  updated_at?: string;
}

export type TelemetryRange = '1m' | '15m' | '1h' | '24h' | '7d';
export type CsvTelemetryRange = '1h' | '24h' | '7d' | '30d';

export interface TelemetrySeriesPoint {
  bucket_at: string;
  voltage_v: number | null;
  voltage_min_v: number | null;
  voltage_max_v: number | null;
  current_a: number | null;
  current_max_a: number | null;
  active_power_w: number | null;
  active_power_max_w: number | null;
  power_factor: number | null;
  power_factor_min: number | null;
  frequency_hz: number | null;
  frequency_min_hz: number | null;
  frequency_max_hz: number | null;
  energy_start_wh: number | null;
  energy_end_wh: number | null;
  samples: number;
}

export interface TelemetrySeriesResponse {
  device_id: string;
  range: TelemetryRange;
  range_seconds: number;
  bucket_seconds: number;
  items: TelemetrySeriesPoint[];
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
    const response = await fetch(`${apiBase()}${path}`, { headers: { Accept: 'application/json' } });
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
    source: item.source ?? undefined,
    value: item.value ?? undefined,
    threshold: item.threshold ?? undefined,
  }));
}

export async function fetchTelemetrySeries(range: TelemetryRange): Promise<TelemetrySeriesResponse | null> {
  return getJson<TelemetrySeriesResponse>(
    `/api/v1/devices/${encodeURIComponent(deviceId())}/telemetry/series?range=${range}`,
  );
}

export async function fetchDeviceSettings(): Promise<DeviceSettingsResponse | null> {
  return getJson<DeviceSettingsResponse>(
    `/api/v1/devices/${encodeURIComponent(deviceId())}/settings`,
  );
}

export async function saveDeviceSettings(thresholds: AlarmThresholds): Promise<DeviceSettingsResponse> {
  const response = await fetch(
    `${apiBase()}/api/v1/devices/${encodeURIComponent(deviceId())}/settings`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(thresholds),
    },
  );

  if (!response.ok) {
    let message = `Erreur HTTP ${response.status}`;
    try {
      const payload = await response.json();
      message = payload.detail ?? message;
    } catch {
      // Le message HTTP générique reste utilisé.
    }
    throw new Error(message);
  }

  return (await response.json()) as DeviceSettingsResponse;
}


export function telemetryCsvUrl(range: CsvTelemetryRange): string {
  return `${apiBase()}/api/v1/devices/${encodeURIComponent(deviceId())}/exports/telemetry.csv?range=${range}`;
}

export function sessionsCsvUrl(): string {
  return `${apiBase()}/api/v1/devices/${encodeURIComponent(deviceId())}/exports/sessions.csv`;
}

export function eventsCsvUrl(): string {
  return `${apiBase()}/api/v1/devices/${encodeURIComponent(deviceId())}/exports/events.csv`;
}
