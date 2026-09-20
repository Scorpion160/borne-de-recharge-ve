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
  sample_id?: string;
  boot_id?: number;
  session_id?: string;
  durable_replay?: boolean;
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

export interface CoreStatus {
  schema?: number;
  device_id?: string;
  timestamp?: string;
  online?: boolean;
  state?: StationState;
  firmware?: string;
  pzem_online?: boolean;
  transport_wifi?: boolean;
  transport_ap?: boolean;
  transport_ble?: boolean;
  captive_portal_enabled?: boolean;
  captive_portal_authenticated?: boolean;
  cloud_transport?: string;
  durable_pending?: number;
}

export interface CoreDiagnostics {
  schema?: number;
  device_id?: string;
  timestamp?: string;
  firmware?: string;
  uptime_s?: number;
  free_heap_bytes?: number;
  wifi_connected?: boolean;
  wifi_rssi_dbm?: number;
  wifi_ip?: string;
  ap_ip?: string;
  fallback_ap_active?: boolean;
  mdns?: string;
  captive_portal_enabled?: boolean;
  captive_portal_authenticated?: boolean;
  captive_portal_last_http_code?: number;
  mqtt_connected?: boolean;
  https_fallback_ok?: boolean;
  https_last_http_code?: number;
  https_publish_ok?: number;
  https_publish_errors?: number;
  cloud_transport?: string;
  ble_connected?: boolean;
  pzem_online?: boolean;
  pzem_reads_ok?: number;
  pzem_errors?: number;
  pzem_consecutive_errors?: number;
  pzem_last_error?: string;
  boot_id?: number;
  durable_store_ok?: boolean;
  durable_queue_error?: boolean;
  durable_pending_telemetry?: number;
  durable_pending_bytes?: number;
  durable_pending_summaries?: number;
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
  source?: string;
  value?: number;
  threshold?: number;
}
