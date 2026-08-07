import { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  Bluetooth,
  Cable,
  ChartNoAxesCombined,
  ChevronRight,
  CircleGauge,
  Clock3,
  Database,
  Gauge,
  History,
  LayoutDashboard,
  Radio,
  Server,
  Settings,
  ShieldCheck,
  SlidersHorizontal,
  Wifi,
  Zap,
} from 'lucide-react';
import {
  getFreshHubSession,
  getHubAlerts,
  getHubStationState,
  isHubConnected,
  isHubDataLive,
} from './dataBridge';
import { alerts as simulationAlerts, evolveTelemetry, initialSession, initialTelemetry } from './mock';
import type { AcTelemetry, AlertItem, LiveSession, StationState } from './types';

type Page = 'dashboard' | 'measurements' | 'sessions' | 'alerts' | 'diagnostics';

const navItems: { id: Page; label: string; icon: typeof LayoutDashboard }[] = [
  { id: 'dashboard', label: 'Vue générale', icon: LayoutDashboard },
  { id: 'measurements', label: 'Mesures AC', icon: CircleGauge },
  { id: 'sessions', label: 'Sessions', icon: History },
  { id: 'alerts', label: 'Alarmes', icon: AlertTriangle },
  { id: 'diagnostics', label: 'Diagnostic', icon: SlidersHorizontal },
];

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

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

function MetricCard({
  label,
  value,
  unit,
  detail,
  icon: Icon,
  emphasis = false,
}: {
  label: string;
  value: string;
  unit?: string;
  detail?: string;
  icon: typeof Zap;
  emphasis?: boolean;
}) {
  return (
    <article className={`metric-card ${emphasis ? 'metric-card--emphasis' : ''}`}>
      <div className="metric-card__head">
        <span>{label}</span>
        <Icon size={18} aria-hidden="true" />
      </div>
      <div className="metric-card__value">
        {value} {unit && <small>{unit}</small>}
      </div>
      {detail && <p>{detail}</p>}
    </article>
  );
}

function Sparkline({ values }: { values: number[] }) {
  const points = useMemo(() => {
    if (values.length < 2) return '';
    const min = Math.min(...values);
    const max = Math.max(...values);
    const span = Math.max(max - min, 1);
    return values
      .map((value, index) => {
        const x = (index / (values.length - 1)) * 100;
        const y = 44 - ((value - min) / span) * 34;
        return `${x},${y}`;
      })
      .join(' ');
  }, [values]);

  return (
    <svg className="sparkline" viewBox="0 0 100 48" preserveAspectRatio="none" role="img" aria-label="Évolution récente de la puissance">
      <line x1="0" y1="42" x2="100" y2="42" className="sparkline__grid" />
      <line x1="0" y1="25" x2="100" y2="25" className="sparkline__grid" />
      <line x1="0" y1="8" x2="100" y2="8" className="sparkline__grid" />
      <polyline points={points} className="sparkline__line" />
    </svg>
  );
}

function LinkBadge({ label, state, detail }: { label: string; state: 'online' | 'offline' | 'planned'; detail?: string }) {
  return (
    <div className={`link-badge link-badge--${state}`} title={detail}>
      <span className="link-badge__dot" />
      <span>{label}</span>
      {detail && <small>{detail}</small>}
    </div>
  );
}

function Dashboard({
  telemetry,
  session,
  powerHistory,
  hubLive,
  hubOnline,
  stationState,
}: {
  telemetry: AcTelemetry;
  session: LiveSession;
  powerHistory: number[];
  hubLive: boolean;
  hubOnline: boolean;
  stationState: StationState;
}) {
  return (
    <>
      <section className="hero-grid">
        <MetricCard label="Puissance" value={(telemetry.active_power_w / 1000).toFixed(2)} unit="kW" detail={hubLive ? 'Temps réel · VE-SCOPE Hub' : 'Temps réel · Simulation'} icon={Zap} emphasis />
        <MetricCard label="Énergie session" value={(session.energy_wh / 1000).toFixed(2)} unit="kWh" detail="Depuis le début" icon={Database} />
        <MetricCard label="Durée" value={formatDuration(session.duration_s)} detail={`Démarrée à ${formatTime(session.started_at)}`} icon={Clock3} />
        <MetricCard label="État" value={stationStateLabel(stationState)} detail={hubLive ? 'État reçu de la borne' : 'État simulé'} icon={Activity} />
      </section>

      <section className="panel chart-panel">
        <div className="panel__title-row">
          <div>
            <span className="eyebrow">TEMPS RÉEL</span>
            <h2>Puissance appelée</h2>
          </div>
          <div className="live-chip"><span /> actualisation 1 s</div>
        </div>
        <Sparkline values={powerHistory} />
        <div className="chart-footer">
          <span>Dernière minute</span>
          <strong>{(telemetry.active_power_w / 1000).toFixed(2)} kW</strong>
        </div>
      </section>

      <section className="quick-grid">
        <div><span>Tension</span><strong>{telemetry.voltage_v.toFixed(1)} V</strong></div>
        <div><span>Courant</span><strong>{telemetry.current_a.toFixed(2)} A</strong></div>
        <div><span>Facteur de puissance</span><strong>{telemetry.power_factor.toFixed(3)}</strong></div>
        <div><span>Fréquence</span><strong>{telemetry.frequency_hz.toFixed(2)} Hz</strong></div>
      </section>

      <section className="two-columns">
        <article className="panel">
          <div className="panel__title-row">
            <div>
              <span className="eyebrow">SESSION ACTIVE</span>
              <h2>{session.session_id}</h2>
            </div>
            <ChevronRight size={20} />
          </div>
          <dl className="detail-list">
            <div><dt>Puissance moyenne</dt><dd>{(session.average_power_w / 1000).toFixed(2)} kW</dd></div>
            <div><dt>Puissance maximale</dt><dd>{(session.max_power_w / 1000).toFixed(2)} kW</dd></div>
            <div><dt>Courant maximal</dt><dd>{session.max_current_a.toFixed(2)} A</dd></div>
            <div><dt>PF moyen</dt><dd>{session.average_power_factor.toFixed(3)}</dd></div>
          </dl>
        </article>

        <article className="panel">
          <div className="panel__title-row">
            <div>
              <span className="eyebrow">COMMUNICATIONS</span>
              <h2>État des liaisons</h2>
            </div>
            <Radio size={20} />
          </div>
          <div className="links-stack">
            <LinkBadge label="VE-SCOPE Hub" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'WebSocket connecté' : 'Reconnexion automatique'} />
            <LinkBadge label="MQTT" state={hubLive ? 'online' : 'offline'} detail={hubLive ? 'Télémétrie reçue' : 'Aucune donnée récente'} />
            <LinkBadge label="PZEM" state="online" detail={hubLive ? 'Données via Core' : 'Valeurs simulées'} />
            <LinkBadge label="BMS" state="planned" detail="V1.1" />
            <LinkBadge label="Bluetooth" state="planned" detail="Prévu sur Core" />
          </div>
        </article>
      </section>
    </>
  );
}

function Measurements({ telemetry, hubLive }: { telemetry: AcTelemetry; hubLive: boolean }) {
  const rows = [
    ['Tension efficace', telemetry.voltage_v.toFixed(2), 'V', hubLive ? 'PZEM / Hub' : 'Simulation'],
    ['Courant efficace', telemetry.current_a.toFixed(3), 'A', hubLive ? 'PZEM / Hub' : 'Simulation'],
    ['Puissance active', telemetry.active_power_w.toFixed(1), 'W', hubLive ? 'PZEM / Hub' : 'Simulation'],
    ['Puissance apparente', telemetry.apparent_power_va.toFixed(1), 'VA', 'Calculée'],
    ['Puissance non active', telemetry.non_active_power_var_est.toFixed(1), 'var', 'Estimée'],
    ['Facteur de puissance', telemetry.power_factor.toFixed(3), '—', hubLive ? 'PZEM / Hub' : 'Simulation'],
    ['Fréquence', telemetry.frequency_hz.toFixed(3), 'Hz', hubLive ? 'PZEM / Hub' : 'Simulation'],
    ['Énergie totale', (telemetry.energy_total_wh / 1000).toFixed(3), 'kWh', hubLive ? 'PZEM / Hub' : 'Simulation'],
  ];

  return (
    <section className="panel">
      <div className="panel__title-row">
        <div><span className="eyebrow">PZEM-004T</span><h2>Mesures électriques AC</h2></div>
        <span className="quality-badge">{telemetry.quality}</span>
      </div>
      <div className="measurement-table">
        {rows.map(([name, value, unit, source]) => (
          <div className="measurement-row" key={name}>
            <span>{name}</span><strong>{value} <small>{unit}</small></strong><em>{source}</em>
          </div>
        ))}
      </div>
      <p className="note">La puissance non active est une estimation dérivée de S et P. Elle ne remplace pas une mesure de puissance réactive par analyseur de puissance.</p>
    </section>
  );
}

function Sessions({ session, hubLive }: { session: LiveSession; hubLive: boolean }) {
  return (
    <section className="panel">
      <div className="panel__title-row"><div><span className="eyebrow">HISTORIQUE</span><h2>Sessions de recharge</h2></div><History size={20} /></div>
      <div className="session-table">
        <div className="session-table__head"><span>Session</span><span>Durée</span><span>Énergie</span><span>P max</span><span>État</span></div>
        <div className="session-table__row"><span>{session.session_id}</span><span>{formatDuration(session.duration_s)}</span><span>{(session.energy_wh / 1000).toFixed(2)} kWh</span><span>{(session.max_power_w / 1000).toFixed(2)} kW</span><span className="status-text">{hubLive ? 'En cours · Hub' : 'En cours · Simulation'}</span></div>
        <div className="session-table__row muted"><span>VE01-20260806-142500</span><span>03:18:12</span><span>6.85 kWh</span><span>2.21 kW</span><span>Terminée</span></div>
        <div className="session-table__row muted"><span>VE01-20260806-091200</span><span>00:24:08</span><span>0.81 kWh</span><span>2.18 kW</span><span>Interrompue</span></div>
      </div>
    </section>
  );
}

function Alerts({ items }: { items: AlertItem[] }) {
  return (
    <section className="panel">
      <div className="panel__title-row"><div><span className="eyebrow">JOURNAL</span><h2>Alarmes et événements</h2></div><ShieldCheck size={20} /></div>
      <div className="event-list">
        {items.map((item) => (
          <div className="event" key={item.id}>
            <span className={`severity severity--${item.severity.toLowerCase()}`}>{item.severity}</span>
            <div><strong>{item.message}</strong><small>{item.code} · {formatTime(item.timestamp)}</small></div>
          </div>
        ))}
      </div>
    </section>
  );
}

function Diagnostics({ telemetry, hubLive, hubOnline }: { telemetry: AcTelemetry; hubLive: boolean; hubOnline: boolean }) {
  return (
    <div className="two-columns">
      <section className="panel">
        <div className="panel__title-row"><div><span className="eyebrow">VE-SCOPE CORE</span><h2>Diagnostic système</h2></div><Gauge size={20} /></div>
        <dl className="detail-list">
          <div><dt>Firmware</dt><dd>{hubLive ? 'Source VE-SCOPE Core / simulateur MQTT' : 'simulation-ui-0.1.0'}</dd></div>
          <div><dt>PCB</dt><dd>VE-SCOPE Core V1.0 (prévu)</dd></div>
          <div><dt>Source active</dt><dd>{hubLive ? 'VE-SCOPE Hub' : 'Mode simulation local'}</dd></div>
          <div><dt>Dernière séquence</dt><dd>#{telemetry.sequence}</dd></div>
          <div><dt>Qualité donnée</dt><dd>{telemetry.quality}</dd></div>
        </dl>
      </section>
      <section className="panel">
        <div className="panel__title-row"><div><span className="eyebrow">RÉSEAU</span><h2>Communications</h2></div><Server size={20} /></div>
        <div className="links-stack">
          <LinkBadge label="VE-SCOPE Hub" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'WebSocket connecté' : 'Hors ligne'} />
          <LinkBadge label="MQTT" state={hubLive ? 'online' : 'offline'} detail={hubLive ? 'Contrat schema 1 actif' : 'Repli simulation'} />
          <LinkBadge label="Bluetooth" state="planned" detail="Prévu sur Core" />
          <LinkBadge label="USB" state="planned" detail="Console série prévue" />
        </div>
      </section>
    </div>
  );
}

export default function App() {
  const [page, setPage] = useState<Page>('dashboard');
  const [telemetry, setTelemetry] = useState(initialTelemetry);
  const [session, setSession] = useState(initialSession);
  const [hubOnline, setHubOnline] = useState(false);
  const [hubLive, setHubLive] = useState(false);
  const [stationState, setStationState] = useState<StationState>('CHARGING');
  const [eventItems, setEventItems] = useState<AlertItem[]>(simulationAlerts);
  const [powerHistory, setPowerHistory] = useState<number[]>(() => Array.from({ length: 48 }, (_, i) => 2140 + Math.sin(i / 5) * 45));

  useEffect(() => {
    const timer = window.setInterval(() => {
      const connected = isHubConnected();
      const live = isHubDataLive();
      const hubSession = getFreshHubSession();

      setHubOnline(connected);
      setHubLive(live);
      setStationState(live ? getHubStationState() : 'CHARGING');

      const hubEvents = getHubAlerts();
      if (hubEvents.length > 0) {
        const merged = [...hubEvents, ...simulationAlerts].filter(
          (item, index, all) => all.findIndex((candidate) => candidate.id === item.id) === index,
        );
        setEventItems(merged);
      }

      setTelemetry((previous) => {
        const next = evolveTelemetry(previous);
        setPowerHistory((values) => [...values.slice(-59), next.active_power_w]);

        if (hubSession) {
          setSession(hubSession);
        } else {
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

  const content = (() => {
    if (page === 'measurements') return <Measurements telemetry={telemetry} hubLive={hubLive} />;
    if (page === 'sessions') return <Sessions session={session} hubLive={hubLive} />;
    if (page === 'alerts') return <Alerts items={eventItems} />;
    if (page === 'diagnostics') return <Diagnostics telemetry={telemetry} hubLive={hubLive} hubOnline={hubOnline} />;
    return <Dashboard telemetry={telemetry} session={session} powerHistory={powerHistory} hubLive={hubLive} hubOnline={hubOnline} stationState={stationState} />;
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
            <div className="status-pill"><span /> {stationStateLabel(stationState)}</div>
          </div>
        </header>

        <div className="content-area">{content}</div>

        <footer className="footer-status">
          <div><Wifi size={15} /> Hub <strong>{hubOnline ? 'OK' : 'LOCAL'}</strong></div>
          <div><Radio size={15} /> MQTT <strong>{hubLive ? 'LIVE' : 'SIM'}</strong></div>
          <div><Gauge size={15} /> PZEM <strong>{hubLive ? 'LIVE' : 'SIMULÉ'}</strong></div>
          <div><Bluetooth size={15} /> BLE <strong>PRÉVU</strong></div>
          <span>Dernière donnée : {formatTime(telemetry.timestamp)}</span>
        </footer>
      </main>
    </div>
  );
}
