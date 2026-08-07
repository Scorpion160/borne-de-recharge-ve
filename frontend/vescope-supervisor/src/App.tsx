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
import HistoricalAnalysis from './HistoricalAnalysis';
import MeasurementsPage from './MeasurementsPage';
import SessionsPage from './SessionsPage';
import {
  getFreshHubSession,
  getHubAlerts,
  getHubStationState,
  isHubConnected,
  isHubDataLive,
} from './dataBridge';
import {
  fetchHubHealth,
  fetchStoredEvents,
  fetchStoredSessions,
  type StoredSession,
} from './hubApi';
import { alerts as simulationAlerts, evolveTelemetry, initialSession, initialTelemetry } from './mock';
import type { AlertItem, LiveSession, StationState } from './types';

type Page = 'dashboard' | 'measurements' | 'history' | 'sessions' | 'alerts' | 'diagnostics';

const navItems: { id: Page; label: string; icon: typeof LayoutDashboard }[] = [
  { id: 'dashboard', label: 'Vue générale', icon: LayoutDashboard },
  { id: 'measurements', label: 'Mesures AC', icon: CircleGauge },
  { id: 'history', label: 'Historique', icon: ChartNoAxesCombined },
  { id: 'sessions', label: 'Sessions', icon: History },
  { id: 'alerts', label: 'Alarmes', icon: AlertTriangle },
  { id: 'diagnostics', label: 'Diagnostic', icon: SlidersHorizontal },
];

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

function mergeEvents(...groups: AlertItem[][]): AlertItem[] {
  return groups
    .flat()
    .filter((item, index, all) => all.findIndex((candidate) => candidate.id === item.id) === index)
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    .slice(0, 200);
}

export default function App() {
  const [page, setPage] = useState<Page>('dashboard');
  const [telemetry, setTelemetry] = useState(initialTelemetry);
  const [session, setSession] = useState<LiveSession>(initialSession);
  const [storedSessions, setStoredSessions] = useState<StoredSession[]>([]);
  const [hubOnline, setHubOnline] = useState(false);
  const [hubLive, setHubLive] = useState(false);
  const [databaseOnline, setDatabaseOnline] = useState(false);
  const [stationState, setStationState] = useState<StationState>('CHARGING');
  const [eventItems, setEventItems] = useState<AlertItem[]>(simulationAlerts);
  const [powerHistory, setPowerHistory] = useState<number[]>(() =>
    Array.from({ length: 48 }, (_, index) => 2140 + Math.sin(index / 5) * 45),
  );

  useEffect(() => {
    const timer = window.setInterval(() => {
      const connected = isHubConnected();
      const live = isHubDataLive();
      const hubSession = getFreshHubSession();

      setHubOnline(connected);
      setHubLive(live);
      setStationState(live ? getHubStationState() : connected ? 'OFFLINE' : 'CHARGING');

      if (live) {
        setEventItems((current) => mergeEvents(getHubAlerts(), current));
      } else if (!connected) {
        setEventItems(simulationAlerts);
      }

      setTelemetry((previous) => {
        const next = evolveTelemetry(previous);
        setPowerHistory((values) => [...values.slice(-59), next.active_power_w]);

        if (hubSession) {
          setSession(hubSession);
        } else if (!connected) {
          setSession((current) => ({
            ...current,
            duration_s: current.duration_s + 1,
            energy_wh: current.energy_wh + next.active_power_w / 3600,
            max_power_w: Math.max(current.max_power_w, next.active_power_w),
            max_current_a: Math.max(current.max_current_a, next.current_a),
          }));
        }

        return next;
      });
    }, 1000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    let mounted = true;

    const refreshHistory = async () => {
      if (!isHubConnected()) {
        if (mounted) setDatabaseOnline(false);
        return;
      }

      const [health, sessions, events] = await Promise.all([
        fetchHubHealth(),
        fetchStoredSessions(100),
        fetchStoredEvents(200),
      ]);
      if (!mounted) return;

      setDatabaseOnline(Boolean(health?.database_connected));
      setStoredSessions(sessions);
      setEventItems(mergeEvents(getHubAlerts(), events));
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
    if (page === 'sessions') return <SessionsPage session={session} hubLive={hubLive} stored={storedSessions} />;
    if (page === 'alerts') return <AlertsPage items={eventItems} hubLive={hubLive} />;
    if (page === 'diagnostics') return <DiagnosticsPage telemetry={telemetry} hubLive={hubLive} hubOnline={hubOnline} />;
    return (
      <DashboardPage
        telemetry={telemetry}
        session={session}
        powerHistory={powerHistory}
        hubLive={hubLive}
        hubOnline={hubOnline}
        stationState={stationState}
      />
    );
  })();

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
        </nav>

        <div className="sidebar__future">
          <span>EXTENSIONS</span>
          <div><ChartNoAxesCombined size={16} /> Batterie / JK BMS <small>V1.1</small></div>
          <div><Zap size={16} /> Charge rapide <small>V2</small></div>
        </div>

        <div className="sidebar__bottom">
          <button><Settings size={18} /> Paramètres</button>
          <div className="mode-pill"><span /> {hubLive ? 'SOURCE HUB' : 'MODE SIMULATION'}</div>
        </div>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <div>
            <span className="eyebrow">BORNE DE RECHARGE VE</span>
            <h1>{navItems.find((item) => item.id === page)?.label}</h1>
          </div>
          <div className="topbar__right">
            <div className="source-chip"><Cable size={16} /> borne-01 · {hubLive ? 'HUB' : 'SIM'}</div>
            <div className={`status-pill status-pill--${stationState.toLowerCase()}`}><span /> {stationStateLabel(stationState)}</div>
          </div>
        </header>

        <div className="content-area">{content}</div>

        <footer className="footer-status">
          <div><Wifi size={15} /> Hub <strong>{hubOnline ? 'OK' : 'LOCAL'}</strong></div>
          <div><Radio size={15} /> MQTT <strong>{hubLive ? 'LIVE' : 'SIM'}</strong></div>
          <div><Gauge size={15} /> PZEM <strong>{hubLive ? 'LIVE' : 'SIMULÉ'}</strong></div>
          <div><Database size={15} /> DB <strong>{databaseOnline ? 'ACTIVE' : '—'}</strong></div>
          <div><Bluetooth size={15} /> BLE <strong>PRÉVU</strong></div>
          <span>Dernière donnée : {formatTime(telemetry.timestamp)}</span>
        </footer>
      </main>
    </div>
  );
}
