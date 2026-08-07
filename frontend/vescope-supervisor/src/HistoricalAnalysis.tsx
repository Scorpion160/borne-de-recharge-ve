import { useEffect, useMemo, useState } from 'react';
import { Activity, BarChart3, Clock3, Database, RefreshCw } from 'lucide-react';
import {
  fetchTelemetrySeries,
  type TelemetryRange,
  type TelemetrySeriesPoint,
} from './hubApi';

type MetricKey = 'active_power_w' | 'voltage_v' | 'current_a' | 'power_factor' | 'frequency_hz';

const RANGES: { id: TelemetryRange; label: string }[] = [
  { id: '1m', label: '1 min' },
  { id: '15m', label: '15 min' },
  { id: '1h', label: '1 h' },
  { id: '24h', label: '24 h' },
  { id: '7d', label: '7 j' },
];

const METRICS: Record<MetricKey, { label: string; unit: string; decimals: number; scale: number }> = {
  active_power_w: { label: 'Puissance active', unit: 'kW', decimals: 2, scale: 1000 },
  voltage_v: { label: 'Tension', unit: 'V', decimals: 1, scale: 1 },
  current_a: { label: 'Courant', unit: 'A', decimals: 2, scale: 1 },
  power_factor: { label: 'Facteur de puissance', unit: '', decimals: 3, scale: 1 },
  frequency_hz: { label: 'Fréquence', unit: 'Hz', decimals: 2, scale: 1 },
};

function average(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function validValues(points: TelemetrySeriesPoint[], key: MetricKey): number[] {
  return points
    .map((point) => point[key])
    .filter((value): value is number => typeof value === 'number' && Number.isFinite(value));
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(new Date(value));
}

function SeriesChart({ points, metric }: { points: TelemetrySeriesPoint[]; metric: MetricKey }) {
  const config = METRICS[metric];
  const values = validValues(points, metric).map((value) => value / config.scale);

  const geometry = useMemo(() => {
    if (values.length < 2) return { polyline: '', min: 0, max: 0 };
    const min = Math.min(...values);
    const max = Math.max(...values);
    const span = Math.max(max - min, Math.abs(max) * 0.002, 0.001);
    const polyline = values
      .map((value, index) => {
        const x = 4 + (index / (values.length - 1)) * 92;
        const y = 40 - ((value - min) / span) * 32;
        return `${x},${y}`;
      })
      .join(' ');
    return { polyline, min, max };
  }, [values]);

  if (points.length < 2 || values.length < 2) {
    return <div className="history-empty">Pas encore assez de données pour tracer cette période.</div>;
  }

  return (
    <div className="history-chart-wrap">
      <div className="history-axis history-axis--top">
        {geometry.max.toFixed(config.decimals)} {config.unit}
      </div>
      <svg className="history-chart" viewBox="0 0 100 46" preserveAspectRatio="none" role="img" aria-label={`Historique ${config.label}`}>
        <line x1="4" y1="8" x2="96" y2="8" className="history-chart__grid" />
        <line x1="4" y1="24" x2="96" y2="24" className="history-chart__grid" />
        <line x1="4" y1="40" x2="96" y2="40" className="history-chart__grid" />
        <polyline points={geometry.polyline} className="history-chart__line" />
      </svg>
      <div className="history-axis history-axis--bottom">
        {geometry.min.toFixed(config.decimals)} {config.unit}
      </div>
      <div className="history-time-axis">
        <span>{formatDateTime(points[0].bucket_at)}</span>
        <span>{formatDateTime(points[points.length - 1].bucket_at)}</span>
      </div>
    </div>
  );
}

export default function HistoricalAnalysis() {
  const [range, setRange] = useState<TelemetryRange>('15m');
  const [metric, setMetric] = useState<MetricKey>('active_power_w');
  const [points, setPoints] = useState<TelemetrySeriesPoint[]>([]);
  const [bucketSeconds, setBucketSeconds] = useState(0);
  const [loading, setLoading] = useState(true);
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);

  useEffect(() => {
    let mounted = true;

    const refresh = async () => {
      const response = await fetchTelemetrySeries(range);
      if (!mounted) return;
      if (response) {
        setPoints(response.items);
        setBucketSeconds(response.bucket_seconds);
        setLastRefresh(new Date());
      }
      setLoading(false);
    };

    setLoading(true);
    void refresh();
    const timer = window.setInterval(() => void refresh(), range === '1m' || range === '15m' ? 5000 : 15000);
    return () => {
      mounted = false;
      window.clearInterval(timer);
    };
  }, [range]);

  const stats = useMemo(() => {
    const powers = validValues(points, 'active_power_w');
    const voltages = validValues(points, 'voltage_v');
    const currents = validValues(points, 'current_a');
    const powerFactors = validValues(points, 'power_factor');
    const sampleCount = points.reduce((sum, point) => sum + Number(point.samples || 0), 0);
    const energyStarts = points.map((point) => point.energy_start_wh).filter((value): value is number => typeof value === 'number');
    const energyEnds = points.map((point) => point.energy_end_wh).filter((value): value is number => typeof value === 'number');
    const energyDelta = energyStarts.length && energyEnds.length
      ? Math.max(0, Math.max(...energyEnds) - Math.min(...energyStarts))
      : 0;

    return {
      averagePowerW: average(powers),
      maxPowerW: powers.length ? Math.max(...powers) : 0,
      minVoltageV: voltages.length ? Math.min(...voltages) : 0,
      maxVoltageV: voltages.length ? Math.max(...voltages) : 0,
      maxCurrentA: currents.length ? Math.max(...currents) : 0,
      averagePowerFactor: average(powerFactors),
      sampleCount,
      energyDeltaWh: energyDelta,
    };
  }, [points]);

  const config = METRICS[metric];
  const selectedValues = validValues(points, metric).map((value) => value / config.scale);
  const selectedAverage = average(selectedValues);

  return (
    <div className="history-page">
      <section className="panel history-toolbar-panel">
        <div className="panel__title-row">
          <div>
            <span className="eyebrow">POSTGRESQL · ANALYSE</span>
            <h2>Historique des mesures AC</h2>
          </div>
          <div className="history-refresh">
            <RefreshCw size={16} className={loading ? 'spin' : ''} />
            <span>{lastRefresh ? lastRefresh.toLocaleTimeString('fr-FR') : 'chargement'}</span>
          </div>
        </div>
        <div className="history-range-list">
          {RANGES.map((item) => (
            <button key={item.id} className={range === item.id ? 'active' : ''} onClick={() => setRange(item.id)}>
              {item.label}
            </button>
          ))}
        </div>
      </section>

      <section className="history-kpis">
        <article className="history-kpi"><BarChart3 size={18} /><span>Puissance moyenne</span><strong>{(stats.averagePowerW / 1000).toFixed(2)} kW</strong></article>
        <article className="history-kpi"><Activity size={18} /><span>Puissance maximale</span><strong>{(stats.maxPowerW / 1000).toFixed(2)} kW</strong></article>
        <article className="history-kpi"><Database size={18} /><span>Énergie période</span><strong>{(stats.energyDeltaWh / 1000).toFixed(3)} kWh</strong></article>
        <article className="history-kpi"><Clock3 size={18} /><span>Échantillons</span><strong>{stats.sampleCount}</strong></article>
      </section>

      <section className="panel">
        <div className="history-metric-tabs">
          {(Object.keys(METRICS) as MetricKey[]).map((key) => (
            <button key={key} className={metric === key ? 'active' : ''} onClick={() => setMetric(key)}>
              {METRICS[key].label}
            </button>
          ))}
        </div>
        <div className="history-chart-head">
          <div>
            <span className="eyebrow">COURBE AGRÉGÉE</span>
            <h2>{config.label}</h2>
          </div>
          <div className="history-current-stat">
            <span>Moyenne</span>
            <strong>{selectedAverage.toFixed(config.decimals)} {config.unit}</strong>
          </div>
        </div>
        <SeriesChart points={points} metric={metric} />
        <div className="history-meta">
          <span>Pas d'agrégation : {bucketSeconds || '—'} s</span>
          <span>{points.length} points affichés</span>
        </div>
      </section>

      <section className="history-kpis history-kpis--secondary">
        <article className="history-kpi"><span>Tension min.</span><strong>{stats.minVoltageV.toFixed(1)} V</strong></article>
        <article className="history-kpi"><span>Tension max.</span><strong>{stats.maxVoltageV.toFixed(1)} V</strong></article>
        <article className="history-kpi"><span>Courant max.</span><strong>{stats.maxCurrentA.toFixed(2)} A</strong></article>
        <article className="history-kpi"><span>PF moyen</span><strong>{stats.averagePowerFactor.toFixed(3)}</strong></article>
      </section>
    </div>
  );
}
