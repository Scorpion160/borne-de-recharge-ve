import { getFreshHubTelemetry } from './dataBridge';
import type { AcTelemetry, AlertItem, LinkStatus, LiveSession } from './types';

const now = Date.now();

export const initialTelemetry: AcTelemetry = {
  schema: 1,
  device_id: 'borne-01',
  timestamp: new Date().toISOString(),
  sequence: 1542,
  quality: 'GOOD',
  voltage_v: 230.4,
  current_a: 9.73,
  active_power_w: 2160,
  apparent_power_va: 2241,
  non_active_power_var_est: 597,
  power_factor: 0.964,
  frequency_hz: 50.01,
  energy_total_wh: 15432,
};

export const initialSession: LiveSession = {
  session_id: 'VE01-20260807-061522',
  state: 'CHARGING',
  started_at: new Date(now - 2.52 * 3600_000).toISOString(),
  duration_s: Math.round(2.52 * 3600),
  energy_wh: 5430,
  average_power_w: 2152,
  max_power_w: 2221,
  max_current_a: 9.95,
  average_power_factor: 0.968,
};

export const links: LinkStatus[] = [
  { label: 'Wi-Fi', state: 'online', detail: '-58 dBm' },
  { label: 'MQTT', state: 'online', detail: 'Connecté' },
  { label: 'PZEM', state: 'online', detail: 'Modbus OK' },
  { label: 'BMS', state: 'planned', detail: 'V1.1' },
  { label: 'Internet', state: 'online', detail: 'Disponible' },
];

export const alerts: AlertItem[] = [
  {
    id: 'evt-001',
    timestamp: new Date(now - 18 * 60_000).toISOString(),
    severity: 'INFO',
    code: 'SESSION_STARTED',
    message: 'Session de recharge démarrée automatiquement.',
  },
  {
    id: 'evt-002',
    timestamp: new Date(now - 5 * 60_000).toISOString(),
    severity: 'INFO',
    code: 'MQTT_CONNECTED',
    message: 'Connexion MQTT opérationnelle.',
  },
];

export function evolveTelemetry(previous: AcTelemetry): AcTelemetry {
  const live = getFreshHubTelemetry();
  if (live) return live;

  const voltage = 230 + Math.sin(previous.sequence / 9) * 1.6 + (Math.random() - 0.5) * 0.6;
  const current = 9.65 + Math.sin(previous.sequence / 6) * 0.22 + (Math.random() - 0.5) * 0.12;
  const pf = Math.min(0.99, Math.max(0.94, 0.971 + (Math.random() - 0.5) * 0.012));
  const apparent = voltage * current;
  const active = apparent * pf;
  const q = Math.sqrt(Math.max(apparent * apparent - active * active, 0));

  return {
    ...previous,
    timestamp: new Date().toISOString(),
    sequence: previous.sequence + 1,
    voltage_v: voltage,
    current_a: current,
    active_power_w: active,
    apparent_power_va: apparent,
    non_active_power_var_est: q,
    power_factor: pf,
    frequency_hz: 50 + (Math.random() - 0.5) * 0.04,
    energy_total_wh: previous.energy_total_wh + active / 3600,
  };
}
