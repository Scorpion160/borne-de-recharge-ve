import type { AcTelemetry, AlertItem, LiveSession, StationState } from './types';

let latestTelemetry: AcTelemetry | null = null;
let latestTelemetryAt = 0;
let latestSession: LiveSession | null = null;
let latestSessionAt = 0;
let latestAlerts: AlertItem[] = [];
let stationState: StationState = 'OFFLINE';
let hubConnected = false;

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

export function getFreshHubTelemetry(maxAgeMs = 3500): AcTelemetry | null {
  if (!hubConnected || !latestTelemetry) return null;
  if (Date.now() - latestTelemetryAt > maxAgeMs) return null;
  return latestTelemetry;
}

export function setHubSession(value: LiveSession): void {
  latestSession = value;
  latestSessionAt = Date.now();
}

export function getFreshHubSession(maxAgeMs = 3500): LiveSession | null {
  if (!hubConnected || !latestSession) return null;
  if (Date.now() - latestSessionAt > maxAgeMs) return null;
  return latestSession;
}

export function pushHubAlert(value: AlertItem): void {
  latestAlerts = [value, ...latestAlerts.filter((item) => item.id !== value.id)].slice(0, 100);
}

export function getHubAlerts(): AlertItem[] {
  return latestAlerts;
}

export function isHubDataLive(maxAgeMs = 3500): boolean {
  return getFreshHubTelemetry(maxAgeMs) !== null;
}
