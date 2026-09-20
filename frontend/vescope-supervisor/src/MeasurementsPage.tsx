import { Fingerprint, Radio } from 'lucide-react';
import type { AcTelemetry } from './types';

function qualityClass(quality: string): string {
  if (quality === 'GOOD') return 'quality-badge quality-badge--good';
  if (quality === 'STALE') return 'quality-badge quality-badge--stale';
  if (quality === 'INVALID') return 'quality-badge quality-badge--invalid';
  if (quality === 'ESTIMATED') return 'quality-badge quality-badge--estimated';
  return 'quality-badge quality-badge--unavailable';
}

export default function MeasurementsPage({ telemetry, hubLive }: { telemetry: AcTelemetry | null; hubLive: boolean }) {
  if (!telemetry) {
    return (
      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">PZEM-004T</span><h2>Mesures électriques AC</h2></div>
          <span className="quality-badge quality-badge--unavailable">UNAVAILABLE</span>
        </div>
        <p className="note">Aucune mesure réelle n'a encore été reçue depuis la borne.</p>
      </section>
    );
  }

  const displayedQuality = hubLive ? telemetry.quality : 'STALE';
  const source = telemetry.durable_replay
    ? 'PZEM / Hub · relecture de la file durable'
    : hubLive
      ? 'PZEM / Hub · temps réel'
      : 'PZEM / Hub · dernière mesure réelle';
  const rows = [
    ['Tension efficace', telemetry.voltage_v.toFixed(2), 'V', source],
    ['Courant efficace', telemetry.current_a.toFixed(3), 'A', source],
    ['Puissance active', telemetry.active_power_w.toFixed(1), 'W', source],
    ['Puissance apparente', telemetry.apparent_power_va.toFixed(1), 'VA', 'Calculée depuis la mesure réelle'],
    ['Puissance non active', telemetry.non_active_power_var_est.toFixed(1), 'var', 'Estimée depuis S et P'],
    ['Facteur de puissance', telemetry.power_factor.toFixed(3), '—', source],
    ['Fréquence', telemetry.frequency_hz.toFixed(3), 'Hz', source],
    ['Énergie totale compteur', (telemetry.energy_total_wh / 1000).toFixed(3), 'kWh', source],
  ];

  return (
    <div className="measurements-page">
      <section className="panel measurements-main-panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">PZEM-004T · MESURE RÉELLE</span><h2>Mesures électriques AC</h2></div>
          <span className={qualityClass(displayedQuality)}>{displayedQuality}</span>
        </div>
        <div className="measurement-table">
          {rows.map(([name, value, unit, rowSource]) => (
            <div className="measurement-row" key={name}>
              <span>{name}</span><strong>{value} <small>{unit}</small></strong><em>{rowSource}</em>
            </div>
          ))}
        </div>
        <p className="note">Horodatage de la mesure : {new Date(telemetry.timestamp).toLocaleString('fr-FR')}. La puissance non active est une estimation dérivée de la puissance apparente S et de la puissance active P.</p>
      </section>

      <section className="measurement-provenance-grid">
        <article className="panel measurement-provenance-card">
          <div className="measurement-provenance-card__head"><Fingerprint size={18} /><div><span className="eyebrow">IDENTITÉ ÉCHANTILLON</span><h3>Traçabilité</h3></div></div>
          <dl className="detail-list">
            <div><dt>Device ID</dt><dd>{telemetry.device_id}</dd></div>
            <div><dt>Boot ID</dt><dd>{telemetry.boot_id ?? 'Legacy / non fourni'}</dd></div>
            <div><dt>Séquence</dt><dd>#{telemetry.sequence}</dd></div>
            <div><dt>Sample ID</dt><dd className="measurement-code">{telemetry.sample_id ?? 'Legacy / non fourni'}</dd></div>
          </dl>
        </article>

        <article className="panel measurement-provenance-card">
          <div className="measurement-provenance-card__head"><Radio size={18} /><div><span className="eyebrow">ACHEMINEMENT</span><h3>Contexte de réception</h3></div></div>
          <dl className="detail-list">
            <div><dt>État temps réel</dt><dd>{hubLive ? 'LIVE' : 'STALE'}</dd></div>
            <div><dt>Relecture durable</dt><dd>{telemetry.durable_replay ? 'Oui' : 'Non'}</dd></div>
            <div><dt>Session associée</dt><dd>{telemetry.session_id ?? 'Aucune'}</dd></div>
            <div><dt>Qualité déclarée</dt><dd>{telemetry.quality}</dd></div>
          </dl>
        </article>
      </section>
    </div>
  );
}
