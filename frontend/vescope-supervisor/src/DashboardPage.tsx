import { useMemo } from 'react';
import { Activity, Bluetooth, Clock3, Database, Radio, Wifi, Zap } from 'lucide-react';
import type { AcTelemetry, CoreDiagnostics, CoreStatus, LiveSession, StationState } from './types';

type LinkState = 'online' | 'offline' | 'planned' | 'warning' | 'ready';

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function formatTime(iso: string): string {
  return new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(new Date(iso));
}

function stationStateLabel(state: StationState): string {
  const labels: Record<StationState, string> = {
    OFFLINE: 'HORS LIGNE', IDLE: 'DISPONIBLE', SESSION_STARTING: 'DÉMARRAGE', CHARGING: 'EN CHARGE',
    CHARGING_LIMITED: 'CHARGE LIMITÉE', FINISHING: 'FIN DE CHARGE', COMPLETE: 'CHARGE TERMINÉE',
    INTERRUPTED: 'INTERROMPUE', FAULT: 'DÉFAUT', MAINTENANCE: 'MAINTENANCE',
  };
  return labels[state];
}

function MetricCard({ label, value, unit, detail, icon: Icon, emphasis = false }: {
  label: string; value: string; unit?: string; detail?: string; icon: typeof Zap; emphasis?: boolean;
}) {
  return (
    <article className={`metric-card ${emphasis ? 'metric-card--emphasis' : ''}`}>
      <div className="metric-card__head"><span>{label}</span><Icon size={18} /></div>
      <div className="metric-card__value">{value} {unit && <small>{unit}</small>}</div>
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
    return values.map((value, index) => {
      const x = (index / (values.length - 1)) * 100;
      const y = 44 - ((value - min) / span) * 34;
      return `${x},${y}`;
    }).join(' ');
  }, [values]);

  return (
    <svg className="sparkline" viewBox="0 0 100 48" preserveAspectRatio="none" role="img" aria-label="Évolution récente de la puissance réelle">
      <line x1="0" y1="42" x2="100" y2="42" className="sparkline__grid" />
      <line x1="0" y1="25" x2="100" y2="25" className="sparkline__grid" />
      <line x1="0" y1="8" x2="100" y2="8" className="sparkline__grid" />
      <polyline points={points} className="sparkline__line" />
    </svg>
  );
}

function LinkBadge({ label, state, detail }: { label: string; state: LinkState; detail?: string }) {
  return (
    <div className={`link-badge link-badge--${state}`} title={detail}>
      <span className="link-badge__dot" /><span>{label}</span>{detail && <small>{detail}</small>}
    </div>
  );
}

export default function DashboardPage({
  telemetry,
  session,
  powerHistory,
  hubLive,
  hubOnline,
  stationState,
  status,
  diagnostics,
}: {
  telemetry: AcTelemetry | null;
  session: LiveSession | null;
  powerHistory: number[];
  hubLive: boolean;
  hubOnline: boolean;
  stationState: StationState;
  status: CoreStatus | null;
  diagnostics: CoreDiagnostics | null;
}) {
  const telemetryDetail = telemetry
    ? hubLive
      ? `Mesure réelle · ${formatTime(telemetry.timestamp)}`
      : `Dernière mesure réelle · ${formatTime(telemetry.timestamp)}`
    : 'En attente des données de la borne';

  const pzemOnline = hubLive && telemetry
    ? true
    : (status?.pzem_online ?? diagnostics?.pzem_online ?? false);
  const wifiOnline = status?.transport_wifi ?? diagnostics?.wifi_connected;
  const wifiRssi = diagnostics?.wifi_rssi_dbm;
  const wifiWeak = wifiOnline && wifiRssi !== undefined && wifiRssi <= -85;
  const wifiState: LinkState = wifiOnline ? (wifiWeak ? 'warning' : 'online') : 'offline';
  const wifiDetail = wifiRssi !== undefined
    ? `${wifiRssi} dBm${wifiWeak ? ' · signal faible' : ''}`
    : 'État remonté par le Core';
  const bleState: LinkState = diagnostics
    ? (diagnostics.ble_connected ? 'online' : 'ready')
    : 'planned';

  return (
    <>
      <section className="hero-grid">
        <MetricCard label="Puissance" value={telemetry ? (telemetry.active_power_w / 1000).toFixed(2) : '—'} unit={telemetry ? 'kW' : undefined} detail={telemetryDetail} icon={Zap} emphasis />
        <MetricCard label="Énergie session" value={session ? (session.energy_wh / 1000).toFixed(2) : '—'} unit={session ? 'kWh' : undefined} detail={session ? 'Depuis le début de la session réelle' : 'Aucune session active'} icon={Database} />
        <MetricCard label="Durée" value={session ? formatDuration(session.duration_s) : '—'} detail={session ? `Démarrée à ${formatTime(session.started_at)}` : 'Aucune session active'} icon={Clock3} />
        <MetricCard label="État" value={stationStateLabel(stationState)} detail={hubOnline ? 'État reçu de VE-SCOPE Hub' : 'Hub indisponible'} icon={Activity} />
      </section>

      <section className="panel chart-panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">DONNÉES RÉELLES</span><h2>Puissance appelée</h2></div>
          <div className="live-chip"><span /> {hubLive ? 'flux actif' : 'en attente'}</div>
        </div>
        {powerHistory.length >= 2 ? <Sparkline values={powerHistory} /> : <div className="history-empty dashboard-history-empty">En attente de plusieurs mesures réelles pour tracer la courbe.</div>}
        <div className="chart-footer"><span>Mesures reçues récemment</span><strong>{telemetry ? `${(telemetry.active_power_w / 1000).toFixed(2)} kW` : '—'}</strong></div>
      </section>

      <section className="quick-grid">
        <div><span>Tension</span><strong>{telemetry ? `${telemetry.voltage_v.toFixed(1)} V` : '—'}</strong></div>
        <div><span>Courant</span><strong>{telemetry ? `${telemetry.current_a.toFixed(2)} A` : '—'}</strong></div>
        <div><span>Facteur de puissance</span><strong>{telemetry ? telemetry.power_factor.toFixed(3) : '—'}</strong></div>
        <div><span>Fréquence</span><strong>{telemetry ? `${telemetry.frequency_hz.toFixed(2)} Hz` : '—'}</strong></div>
      </section>

      <section className="two-columns">
        <article className="panel">
          <div className="panel__title-row"><div><span className="eyebrow">SESSION ACTIVE</span><h2>{session?.session_id ?? 'Aucune session active'}</h2></div><Zap size={20} /></div>
          {session ? (
            <dl className="detail-list">
              <div><dt>Puissance moyenne</dt><dd>{(session.average_power_w / 1000).toFixed(2)} kW</dd></div>
              <div><dt>Puissance maximale</dt><dd>{(session.max_power_w / 1000).toFixed(2)} kW</dd></div>
              <div><dt>Courant maximal</dt><dd>{session.max_current_a.toFixed(2)} A</dd></div>
              <div><dt>PF moyen</dt><dd>{session.average_power_factor.toFixed(3)}</dd></div>
            </dl>
          ) : <p className="note">La borne est actuellement hors session de recharge.</p>}
        </article>
        <article className="panel">
          <div className="panel__title-row"><div><span className="eyebrow">COMMUNICATIONS</span><h2>État des liaisons</h2></div><Radio size={20} /></div>
          <div className="links-stack">
            <LinkBadge label="VE-SCOPE Hub" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'WebSocket connecté' : 'Reconnexion automatique'} />
            <LinkBadge label="Télémétrie borne" state={hubLive ? 'online' : 'offline'} detail={hubLive ? 'Donnée réelle récente' : 'Aucune donnée récente'} />
            <LinkBadge label="Wi-Fi Core" state={wifiState} detail={wifiDetail} />
            <LinkBadge label="PZEM" state={pzemOnline ? 'online' : 'offline'} detail={pzemOnline ? (hubLive ? 'Acquisition confirmée par télémétrie récente' : 'Acquisition réelle') : 'Aucune mesure récente'} />
            <LinkBadge label="Bluetooth" state={bleState} detail={diagnostics ? (diagnostics.ble_connected ? 'Client connecté' : 'Service local disponible') : 'Disponible avec Core 0.2.12'} />
            <LinkBadge label="BMS" state="planned" detail="V1.1" />
          </div>
        </article>
      </section>
    </>
  );
}
