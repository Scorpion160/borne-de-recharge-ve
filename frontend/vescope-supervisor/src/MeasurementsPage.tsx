import type { AcTelemetry } from './types';

export default function MeasurementsPage({ telemetry, hubLive }: { telemetry: AcTelemetry | null; hubLive: boolean }) {
  if (!telemetry) {
    return (
      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">PZEM-004T</span><h2>Mesures électriques AC</h2></div>
          <span className="quality-badge">UNAVAILABLE</span>
        </div>
        <p className="note">Aucune mesure réelle n'a encore été reçue depuis la borne.</p>
      </section>
    );
  }

  const source = hubLive ? 'PZEM / Hub · temps réel' : 'PZEM / Hub · dernière mesure réelle';
  const rows = [
    ['Tension efficace', telemetry.voltage_v.toFixed(2), 'V', source],
    ['Courant efficace', telemetry.current_a.toFixed(3), 'A', source],
    ['Puissance active', telemetry.active_power_w.toFixed(1), 'W', source],
    ['Puissance apparente', telemetry.apparent_power_va.toFixed(1), 'VA', 'Calculée depuis la mesure réelle'],
    ['Puissance non active', telemetry.non_active_power_var_est.toFixed(1), 'var', 'Estimée depuis la mesure réelle'],
    ['Facteur de puissance', telemetry.power_factor.toFixed(3), '—', source],
    ['Fréquence', telemetry.frequency_hz.toFixed(3), 'Hz', source],
    ['Énergie totale', (telemetry.energy_total_wh / 1000).toFixed(3), 'kWh', source],
  ];

  return (
    <section className="panel">
      <div className="panel__title-row">
        <div><span className="eyebrow">PZEM-004T</span><h2>Mesures électriques AC</h2></div>
        <span className="quality-badge">{hubLive ? telemetry.quality : 'STALE'}</span>
      </div>
      <div className="measurement-table">
        {rows.map(([name, value, unit, rowSource]) => (
          <div className="measurement-row" key={name}>
            <span>{name}</span><strong>{value} <small>{unit}</small></strong><em>{rowSource}</em>
          </div>
        ))}
      </div>
      <p className="note">Horodatage de la mesure réelle : {new Date(telemetry.timestamp).toLocaleString('fr-FR')}. La puissance non active est une estimation dérivée de S et P.</p>
    </section>
  );
}
