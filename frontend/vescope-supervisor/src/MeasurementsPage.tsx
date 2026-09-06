import type { AcTelemetry } from './types';

export default function MeasurementsPage({ telemetry, hubLive }: { telemetry: AcTelemetry; hubLive: boolean }) {
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
