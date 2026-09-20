import type {
  AcTelemetry,
  AlertItem,
  CoreDiagnostics,
  CoreStatus,
  LiveSession,
  StationState,
} from './types';

let latestTelemetry: AcTelemetry | null = null;
let latestTelemetryAt = 0;
let latestSession: LiveSession | null = null;
let latestSessionAt = 0;
let latestStatus: CoreStatus | null = null;
let latestStatusAt = 0;
let latestDiagnostics: CoreDiagnostics | null = null;
let latestDiagnosticsAt = 0;
let latestAlerts: AlertItem[] = [];
let stationState: StationState = 'OFFLINE';
let hubConnected = false;

const DEFAULT_LIVE_MAX_AGE_MS = 25_000;
const DEFAULT_DIAGNOSTICS_MAX_AGE_MS = 45_000;

export function setHubConnected(value: boolean): void {
  hubConnected = value;
  if (!value) stationState = 'OFFLINE';
}

export function isHubConnected(): boolean {
  return hubConnected;
}

export function setHubStationState(value: StationState): void {
  stationState = value;
}

export function getHubStationState(): StationState {
  return stationState;
}

export function setHubTelemetry(value: AcTelemetry): void {
  latestTelemetry = value;
  latestTelemetryAt = Date.now();
}

export function getFreshHubTelemetry(maxAgeMs = DEFAULT_LIVE_MAX_AGE_MS): AcTelemetry | null {
  if (!hubConnected || !latestTelemetry) return null;
  if (Date.now() - latestTelemetryAt > maxAgeMs) return null;
  return latestTelemetry;
}

export function getLastHubTelemetry(): AcTelemetry | null {
  return latestTelemetry;
}

export function setHubSession(value: LiveSession): void {
  latestSession = value;
  latestSessionAt = Date.now();
}

export function getFreshHubSession(maxAgeMs = DEFAULT_LIVE_MAX_AGE_MS): LiveSession | null {
  if (!hubConnected || !latestSession) return null;
  if (Date.now() - latestSessionAt > maxAgeMs) return null;
  return latestSession;
}

export function setHubStatus(value: CoreStatus): void {
  latestStatus = value;
  latestStatusAt = Date.now();
  if (value.state) stationState = value.state;
}

export function getFreshHubStatus(maxAgeMs = DEFAULT_DIAGNOSTICS_MAX_AGE_MS): CoreStatus | null {
  if (!hubConnected || !latestStatus) return null;
  if (Date.now() - latestStatusAt > maxAgeMs) return null;
  return latestStatus;
}

export function getLastHubStatus(): CoreStatus | null {
  return latestStatus;
}

export function setHubDiagnostics(value: CoreDiagnostics): void {
  latestDiagnostics = value;
  latestDiagnosticsAt = Date.now();
}

export function getFreshHubDiagnostics(maxAgeMs = DEFAULT_DIAGNOSTICS_MAX_AGE_MS): CoreDiagnostics | null {
  if (!hubConnected || !latestDiagnostics) return null;
  if (Date.now() - latestDiagnosticsAt > maxAgeMs) return null;
  return latestDiagnostics;
}

export function getLastHubDiagnostics(): CoreDiagnostics | null {
  return latestDiagnostics;
}

export function pushHubAlert(value: AlertItem): void {
  latestAlerts = [value, ...latestAlerts.filter((item) => item.id !== value.id)].slice(0, 100);
}

export function getHubAlerts(): AlertItem[] {
  return latestAlerts;
}

export function isHubDataLive(maxAgeMs = DEFAULT_LIVE_MAX_AGE_MS): boolean {
  return getFreshHubTelemetry(maxAgeMs) !== null;
}
