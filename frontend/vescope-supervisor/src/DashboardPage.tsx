import { useMemo } from 'react';
import { Activity, Bluetooth, Clock3, Database, Radio, Zap } from 'lucide-react';
import type { AcTelemetry, LiveSession, StationState } from './types';

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
      <span className="link-badge__dot" /><span>{label}</span>{detail && <small>{detail}</small>}
    </div>
  );
}

export default function DashboardPage({ telemetry, session, powerHistory, hubLive, hubOnline, stationState }: {
  telemetry: AcTelemetry; session: LiveSession; powerHistory: number[]; hubLive: boolean; hubOnline: boolean; stationState: StationState;
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
          <div><span className="eyebrow">TEMPS RÉEL</span><h2>Puissance appelée</h2></div>
          <div className="live-chip"><span /> actualisation 1 s</div>
        </div>
        <Sparkline values={powerHistory} />
        <div className="chart-footer"><span>Dernière minute</span><strong>{(telemetry.active_power_w / 1000).toFixed(2)} kW</strong></div>
      </section>

      <section className="quick-grid">
        <div><span>Tension</span><strong>{telemetry.voltage_v.toFixed(1)} V</strong></div>
        <div><span>Courant</span><strong>{telemetry.current_a.toFixed(2)} A</strong></div>
        <div><span>Facteur de puissance</span><strong>{telemetry.power_factor.toFixed(3)}</strong></div>
        <div><span>Fréquence</span><strong>{telemetry.frequency_hz.toFixed(2)} Hz</strong></div>
      </section>

      <section className="two-columns">
        <article className="panel">
          <div className="panel__title-row"><div><span className="eyebrow">SESSION ACTIVE</span><h2>{session.session_id}</h2></div><Zap size={20} /></div>
          <dl className="detail-list">
            <div><dt>Puissance moyenne</dt><dd>{(session.average_power_w / 1000).toFixed(2)} kW</dd></div>
            <div><dt>Puissance maximale</dt><dd>{(session.max_power_w / 1000).toFixed(2)} kW</dd></div>
            <div><dt>Courant maximal</dt><dd>{session.max_current_a.toFixed(2)} A</dd></div>
            <div><dt>PF moyen</dt><dd>{session.average_power_factor.toFixed(3)}</dd></div>
          </dl>
        </article>
        <article className="panel">
          <div className="panel__title-row"><div><span className="eyebrow">COMMUNICATIONS</span><h2>État des liaisons</h2></div><Radio size={20} /></div>
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
