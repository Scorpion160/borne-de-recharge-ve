import { Gauge, Server } from 'lucide-react';
import type { AcTelemetry } from './types';

function LinkBadge({ label, state, detail }: { label: string; state: 'online' | 'offline' | 'planned'; detail?: string }) {
  return (
    <div className={`link-badge link-badge--${state}`} title={detail}>
      <span className="link-badge__dot" /><span>{label}</span>{detail && <small>{detail}</small>}
    </div>
  );
}

export default function DiagnosticsPage({ telemetry, hubLive, hubOnline }: { telemetry: AcTelemetry | null; hubLive: boolean; hubOnline: boolean }) {
  return (
    <div className="two-columns">
      <section className="panel">
        <div className="panel__title-row"><div><span className="eyebrow">VE-SCOPE CORE</span><h2>Diagnostic système</h2></div><Gauge size={20} /></div>
        <dl className="detail-list">
          <div><dt>Source active</dt><dd>{hubOnline ? 'VE-SCOPE Core via Hub' : 'Hub indisponible'}</dd></div>
          <div><dt>Télémétrie</dt><dd>{hubLive ? 'Donnée réelle récente' : telemetry ? 'Dernière mesure réelle conservée' : 'Indisponible'}</dd></div>
          <div><dt>Dernière séquence</dt><dd>{telemetry ? `#${telemetry.sequence}` : '—'}</dd></div>
          <div><dt>Qualité donnée</dt><dd>{telemetry ? (hubLive ? telemetry.quality : 'STALE') : 'UNAVAILABLE'}</dd></div>
          <div><dt>Horodatage mesure</dt><dd>{telemetry ? new Date(telemetry.timestamp).toLocaleString('fr-FR') : '—'}</dd></div>
        </dl>
      </section>
      <section className="panel">
        <div className="panel__title-row"><div><span className="eyebrow">RÉSEAU</span><h2>Communications</h2></div><Server size={20} /></div>
        <div className="links-stack">
          <LinkBadge label="VE-SCOPE Hub" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'WebSocket connecté' : 'Hors ligne'} />
          <LinkBadge label="Télémétrie borne" state={hubLive ? 'online' : 'offline'} detail={hubLive ? 'Flux réel actif' : 'Aucune donnée récente'} />
          <LinkBadge label="PostgreSQL" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'Historisation via Hub' : 'Indisponible'} />
          <LinkBadge label="Bluetooth" state="planned" detail="Disponible côté Core pour usage local" />
          <LinkBadge label="USB" state="planned" detail="Console série locale" />
        </div>
      </section>
    </div>
  );
}
