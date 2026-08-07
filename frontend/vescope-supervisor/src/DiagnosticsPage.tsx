import { Gauge, Server } from 'lucide-react';
import type { AcTelemetry } from './types';

function LinkBadge({ label, state, detail }: { label: string; state: 'online' | 'offline' | 'planned'; detail?: string }) {
  return (
    <div className={`link-badge link-badge--${state}`} title={detail}>
      <span className="link-badge__dot" /><span>{label}</span>{detail && <small>{detail}</small>}
    </div>
  );
}

export default function DiagnosticsPage({ telemetry, hubLive, hubOnline }: { telemetry: AcTelemetry; hubLive: boolean; hubOnline: boolean }) {
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
          <LinkBadge label="PostgreSQL" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'Historisation via Hub' : 'Indisponible'} />
          <LinkBadge label="Bluetooth" state="planned" detail="Prévu sur Core" />
          <LinkBadge label="USB" state="planned" detail="Console série prévue" />
        </div>
      </section>
    </div>
  );
}
