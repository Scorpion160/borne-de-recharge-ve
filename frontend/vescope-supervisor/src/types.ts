export type DataQuality = 'GOOD' | 'STALE' | 'INVALID' | 'UNAVAILABLE' | 'ESTIMATED';

export type StationState =
  | 'OFFLINE'
  | 'IDLE'
  | 'SESSION_STARTING'
  | 'CHARGING'
  | 'CHARGING_LIMITED'
  | 'FINISHING'
  | 'COMPLETE'
  | 'INTERRUPTED'
  | 'FAULT'
  | 'MAINTENANCE';

export interface AcTelemetry {
  schema: number;
  device_id: string;
  timestamp: string;
  sequence: number;
  quality: DataQuality;
  voltage_v: number;
  current_a: number;
  active_power_w: number;
  apparent_power_va: number;
  non_active_power_var_est: number;
  power_factor: number;
  frequency_hz: number;
  energy_total_wh: number;
}

export interface LiveSession {
  session_id: string;
  state: StationState;
  started_at: string;
  duration_s: number;
  energy_wh: number;
  average_power_w: number;
  max_power_w: number;
  max_current_a: number;
  average_power_factor: number;
}

export interface LinkStatus {
  label: string;
  state: 'online' | 'offline' | 'planned';
  detail?: string;
}

export interface AlertItem {
  id: string;
  timestamp: string;
  severity: 'INFO' | 'WARNING' | 'ALERT' | 'CRITICAL';
  code: string;
  message: string;
}
