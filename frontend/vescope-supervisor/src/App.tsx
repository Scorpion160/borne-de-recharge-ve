import { useEffect, useState } from 'react';
import {
  AlertTriangle,
  Bluetooth,
  Cable,
  ChartNoAxesCombined,
  CircleGauge,
  Database,
  Gauge,
  History,
  LayoutDashboard,
  Radio,
  Settings,
  SlidersHorizontal,
  Wifi,
  Zap,
} from 'lucide-react';
import AlertsPage from './AlertsPage';
import DashboardPage from './DashboardPage';
import DiagnosticsPage from './DiagnosticsPage';
import DataLoggerPage from './DataLoggerPage';
import HistoricalAnalysis from './HistoricalAnalysis';
import MeasurementsPage from './MeasurementsPage';
import SessionsPage from './SessionsPage';
import SettingsPage from './SettingsPage';
import {
  getFreshHubDiagnostics,
  getFreshHubSession,
  getFreshHubStatus,
  getFreshHubTelemetry,
  getHubAlerts,
  getHubStationState,
  isHubConnected,
  isHubDataLive,
} from './dataBridge';
import {
  fetchDeviceSettings,
  fetchHubHealth,
  fetchStoredEvents,
  fetchStoredSessions,
  fetchTelemetrySeries,
  type StoredSession,
} from './hubApi';
import type {
  AcTelemetry,
  AlertItem,
  CoreDiagnostics,
  CoreStatus,
  LiveSession,
  StationState,
} from './types';

type Page = 'dashboard' | 'measurements' | 'history' | 'data' | 'sessions' | 'alerts' | 'diagnostics' | 'settings';

const navItems: { id: Exclude<Page, 'settings'>; label: string; icon: typeof LayoutDashboard }[] = [
  { id: 'dashboard', label: 'Vue générale', icon: LayoutDashboard },
  { id: 'measurements', label: 'Mesures AC', icon: CircleGauge },
  { id: 'history', label: 'Historique', icon: ChartNoAxesCombined },
  { id: 'data', label: 'Données', icon: Database },
  { id: 'sessions', label: 'Sessions', icon: History },
  { id: 'alerts', label: 'Alarmes', icon: AlertTriangle },
  { id: 'diagnostics', label: 'Diagnostic', icon: SlidersHorizontal },
];

const pageTitles: Record<Page, string> = {
  dashboard: 'Vue générale',
  measurements: 'Mesures AC',
  history: 'Historique',
  data: 'Données',
  sessions: 'Sessions',
  alerts: 'Alarmes',
  diagnostics: 'Diagnostic',
  settings: 'Paramètres',
};

const DEFAULT_LIVE_MAX_AGE_MS = 180_000;
const DIAGNOSTICS_MAX_AGE_MS = 45_000;

function formatTime(iso: string): string {
  return new Intl.DateTimeFormat('fr-FR', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(new Date(iso));
}

function stationStateLabel(state: StationState): string {
  const labels: Record<StationState, string> = {
    OFFLINE: 'HORS LIGNE',
    IDLE: 'DISPONIBLE',
    SESSION_STARTING: 'DÉMARRAGE',
    CHARGING: 'EN CHARGE',
    CHARGING_LIMITED: 'CHARGE LIMITÉE',
    FINISHING: 'FIN DE CHARGE',
    COMPLETE: 'CHARGE TERMINÉE',
    INTERRUPTED: 'INTERROMPUE',
    FAULT: 'DÉFAUT',
    MAINTENANCE: 'MAINTENANCE',
  };
  return labels[state];
}

function eventFingerprint(item: AlertItem): string {
  const timestampMs = new Date(item.timestamp).getTime();
  return [
    item.code,
    item.source ?? '',
    Number.isFinite(timestampMs) ? timestampMs : item.timestamp,
    item.value ?? '',
    item.threshold ?? '',
  ].join('|');
}

function mergeEvents(...groups: AlertItem[][]): AlertItem[] {
  const merged = groups.flat();
  const seen = new Set<string>();
  return merged
    .filter((item) => {
      const fingerprint = eventFingerprint(item);
      if (seen.has(fingerprint)) return false;
      seen.add(fingerprint);
      return true;
    })
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    .slice(0, 200);
}

export default function App() {
  const [page, setPage] = useState<Page>('dashboard');
  const [telemetry, setTelemetry] = useState<AcTelemetry | null>(null);
  const [session, setSession] = useState<LiveSession | null>(null);
  const [coreStatus, setCoreStatus] = useState<CoreStatus | null>(null);
  const [diagnostics, setDiagnostics] = useState<CoreDiagnostics | null>(null);
  const [storedSessions, setStoredSessions] = useState<StoredSession[]>([]);
  const [hubOnline, setHubOnline] = useState(false);
  const [hubLive, setHubLive] = useState(false);
  const [databaseOnline, setDatabaseOnline] = useState(false);
  const [stationState, setStationState] = useState<StationState>('OFFLINE');
  const [eventItems, setEventItems] = useState<AlertItem[]>([]);
  const [powerHistory, setPowerHistory] = useState<number[]>([]);
  const [liveMaxAgeMs, setLiveMaxAgeMs] = useState(DEFAULT_LIVE_MAX_AGE_MS);

  useEffect(() => {
    const timer = window.setInterval(() => {
      const connected = isHubConnected();
      const live = isHubDataLive(liveMaxAgeMs);
      const hubTelemetry = getFreshHubTelemetry(liveMaxAgeMs);
      const hubSession = getFreshHubSession(liveMaxAgeMs);
      const diagnosticsMaxAgeMs = Math.max(DIAGNOSTICS_MAX_AGE_MS, liveMaxAgeMs);
      const hubStatus = getFreshHubStatus(diagnosticsMaxAgeMs);
      const hubDiagnostics = getFreshHubDiagnostics(diagnosticsMaxAgeMs);
      const state = connected ? getHubStationState() : 'OFFLINE';

      setHubOnline(connected);
      setHubLive(live);
      setStationState(state);
      setCoreStatus(hubStatus);
      setDiagnostics(hubDiagnostics);

      if (hubTelemetry) {
        setTelemetry((previous) => {
          const isNewSample = !previous
            || previous.timestamp !== hubTelemetry.timestamp
            || previous.sequence !== hubTelemetry.sequence;
          if (isNewSample) {
            setPowerHistory((values) => [...values.slice(-59), hubTelemetry.active_power_w]);
          }
          return hubTelemetry;
        });
      }

      if (state === 'CHARGING' || state === 'CHARGING_LIMITED' || state === 'SESSION_STARTING' || state === 'FINISHING') {
        if (hubSession) setSession(hubSession);
      } else {
        setSession(null);
      }

      if (connected) {
        setEventItems((current) => mergeEvents(getHubAlerts(), current));
      }
    }, 1000);
    return () => window.clearInterval(timer);
  }, [liveMaxAgeMs]);

  useEffect(() => {
    let mounted = true;
    const refreshHistory = async () => {
      const [health, sessions, events, settings, recentSeries] = await Promise.all([
        fetchHubHealth(),
        fetchStoredSessions(100),
        fetchStoredEvents(200),
        fetchDeviceSettings(),
        fetchTelemetrySeries('15m'),
      ]);
      if (!mounted) return;
      setDatabaseOnline(Boolean(health?.database_connected));
      setStoredSessions(sessions);
      setEventItems(mergeEvents(getHubAlerts(), events));

      const staleSeconds = settings?.alarm_thresholds.stale_after_s;
      if (typeof staleSeconds === 'number' && Number.isFinite(staleSeconds)) {
        setLiveMaxAgeMs(Math.max(5_000, Math.min(300_000, staleSeconds * 1000)));
      }

      const recentPowers = (recentSeries?.items ?? [])
        .map((item) => item.active_power_w)
        .filter((value): value is number => typeof value === 'number' && Number.isFinite(value))
        .slice(-60);
      if (recentPowers.length >= 2) setPowerHistory(recentPowers);
    };
    void refreshHistory();
    const timer = window.setInterval(() => void refreshHistory(), 5000);
    return () => {
      mounted = false;
      window.clearInterval(timer);
    };
  }, []);

  const content = (() => {
    if (page === 'measurements') return <MeasurementsPage telemetry={telemetry} hubLive={hubLive} />;
    if (page === 'history') return <HistoricalAnalysis />;
    if (page === 'data') return <DataLoggerPage hubOnline={hubOnline} databaseOnline={databaseOnline} />;
    if (page === 'sessions') return <SessionsPage session={session} hubLive={hubLive} stored={storedSessions} />;
    if (page === 'alerts') return <AlertsPage items={eventItems} />;
    if (page === 'diagnostics') {
      return (
        <DiagnosticsPage
          telemetry={telemetry}
          status={coreStatus}
          diagnostics={diagnostics}
          hubLive={hubLive}
          hubOnline={hubOnline}
          databaseOnline={databaseOnline}
        />
      );
    }
    if (page === 'settings') return <SettingsPage hubOnline={hubOnline && databaseOnline} />;
    return (
      <DashboardPage
        telemetry={telemetry}
        session={session}
        powerHistory={powerHistory}
        hubLive={hubLive}
        hubOnline={hubOnline}
        stationState={stationState}
        status={coreStatus}
        diagnostics={diagnostics}
      />
    );
  })();

  const sourceLabel = hubLive ? 'TEMPS RÉEL' : telemetry ? 'DERNIÈRE MESURE RÉELLE' : 'EN ATTENTE';
  const pzemOnline = hubLive && telemetry
    ? true
    : (coreStatus?.pzem_online ?? diagnostics?.pzem_online ?? false);
  const bleLabel = diagnostics
    ? diagnostics.ble_connected ? 'CONNECTÉ' : 'PRÊT'
    : '—';

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand__mark"><Zap size={22} /></div>
          <div><strong>VE-SCOPE</strong><span>Supervisor</span></div>
        </div>

        <nav className="nav-list" aria-label="Navigation principale">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button key={item.id} className={page === item.id ? 'active' : ''} onClick={() => setPage(item.id)}>
                <Icon size={18} /><span>{item.label}</span>
              </button>
            );
          })}
          <button className={`mobile-settings-nav ${page === 'settings' ? 'active' : ''}`} onClick={() => setPage('settings')}>
            <Settings size={18} /><span>Paramètres</span>
          </button>
        </nav>

        <div className="sidebar__future">
          <span>EXTENSIONS</span>
          <div><ChartNoAxesCombined size={16} /> Batterie / JK BMS <small>V1.1</small></div>
          <div><Zap size={16} /> Charge rapide <small>V2</small></div>
        </div>

        <div className="sidebar__bottom">
          <button className={page === 'settings' ? 'active' : ''} onClick={() => setPage('settings')}>
            <Settings size={18} /> <span>Paramètres</span>
          </button>
          <div className="mode-pill"><span /> {hubOnline ? 'SOURCE BORNE RÉELLE' : 'HUB HORS LIGNE'}</div>
        </div>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <div>
            <span className="eyebrow">BORNE DE RECHARGE VE</span>
            <h1>{pageTitles[page]}</h1>
          </div>
          <div className="topbar__right">
            <div className="source-chip"><Cable size={16} /> borne-01 · {sourceLabel}</div>
            <div className={`status-pill status-pill--${stationState.toLowerCase()}`}><span /> {stationStateLabel(stationState)}</div>
          </div>
        </header>

        <div className="content-area">{content}</div>

        <footer className="footer-status">
          <div><Wifi size={15} /> Hub <strong>{hubOnline ? 'OK' : 'HORS LIGNE'}</strong></div>
          <div><Radio size={15} /> Télémétrie <strong>{hubLive ? 'LIVE' : telemetry ? 'STALE' : '—'}</strong></div>
          <div><Gauge size={15} /> PZEM <strong>{pzemOnline ? 'RÉEL' : '—'}</strong></div>
          <div><Database size={15} /> DB <strong>{databaseOnline ? 'ACTIVE' : '—'}</strong></div>
          <div><Bluetooth size={15} /> BLE <strong>{bleLabel}</strong></div>
          <span>Dernière donnée réelle : {telemetry ? formatTime(telemetry.timestamp) : '—'}</span>
        </footer>
      </main>
    </div>
  );
}
