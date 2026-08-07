import type { AcTelemetry } from './types';

let latestTelemetry: AcTelemetry | null = null;
let latestTelemetryAt = 0;
let hubConnected = false;

export function setHubConnected(value: boolean): void {
  hubConnected = value;
}

export function isHubConnected(): boolean {
  return hubConnected;
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
