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

function numeric(value: number | null | undefined): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function metricValues(points: TelemetrySeriesPoint[], key: MetricKey): number[] {
  return points.map((point) => point[key]).filter(numeric);
}

function weightedAverage(points: TelemetrySeriesPoint[], key: MetricKey): number | null {
  let weightedSum = 0;
  let weight = 0;
  for (const point of points) {
    const value = point[key];
    if (!numeric(value)) continue;
    const samples = Math.max(1, Number(point.samples || 0));
    weightedSum += value * samples;
    weight += samples;
  }
  return weight > 0 ? weightedSum / weight : null;
}

function maxField(
  points: TelemetrySeriesPoint[],
  primary: keyof TelemetrySeriesPoint,
  fallback: MetricKey,
): number | null {
  const values = points
    .map((point) => {
      const preferred = point[primary];
      if (numeric(preferred as number | null)) return preferred as number;
      const backup = point[fallback];
      return numeric(backup) ? backup : null;
    })
    .filter(numeric);
  return values.length ? Math.max(...values) : null;
}

function minField(
  points: TelemetrySeriesPoint[],
  primary: keyof TelemetrySeriesPoint,
  fallback: MetricKey,
): number | null {
  const values = points
    .map((point) => {
      const preferred = point[primary];
      if (numeric(preferred as number | null)) return preferred as number;
      const backup = point[fallback];
      return numeric(backup) ? backup : null;
    })
    .filter(numeric);
  return values.length ? Math.min(...values) : null;
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

function visibleGapCount(points: TelemetrySeriesPoint[], bucketSeconds: number): number {
  if (points.length < 2 || bucketSeconds <= 0) return 0;
  const thresholdMs = Math.max(bucketSeconds * 2.5, bucketSeconds + 2) * 1000;
  let gaps = 0;
  for (let index = 1; index < points.length; index += 1) {
    const previous = new Date(points[index - 1].bucket_at).getTime();
    const current = new Date(points[index].bucket_at).getTime();
    if (Number.isFinite(previous) && Number.isFinite(current) && current - previous > thresholdMs) gaps += 1;
  }
  return gaps;
}

function SeriesChart({
  points,
  metric,
  bucketSeconds,
}: {
  points: TelemetrySeriesPoint[];
  metric: MetricKey;
  bucketSeconds: number;
}) {
  const config = METRICS[metric];

  const geometry = useMemo(() => {
    const samples = points
      .map((point) => {
        const raw = point[metric];
        const timestamp = new Date(point.bucket_at).getTime();
        if (!numeric(raw) || !Number.isFinite(timestamp)) return null;
        return { timestamp, value: raw / config.scale };
      })
      .filter((sample): sample is { timestamp: number; value: number } => sample !== null);

    if (samples.length < 2) return { segments: [] as string[], min: 0, max: 0, first: null as number | null, last: null as number | null };

    const values = samples.map((sample) => sample.value);
    const min = Math.min(...values);
    const max = Math.max(...values);
    const span = Math.max(max - min, Math.abs(max) * 0.002, 0.001);
    const first = samples[0].timestamp;
    const last = samples[samples.length - 1].timestamp;
    const timeSpan = Math.max(last - first, 1);
    const gapThresholdMs = Math.max(bucketSeconds * 2.5, bucketSeconds + 2) * 1000;

    const segments: string[] = [];
    let current: string[] = [];
    let previousTimestamp: number | null = null;

    for (const sample of samples) {
      if (previousTimestamp !== null && sample.timestamp - previousTimestamp > gapThresholdMs) {
        if (current.length >= 2) segments.push(current.join(' '));
        current = [];
      }
      const x = 4 + ((sample.timestamp - first) / timeSpan) * 92;
      const y = 40 - ((sample.value - min) / span) * 32;
      current.push(`${x},${y}`);
      previousTimestamp = sample.timestamp;
    }
    if (current.length >= 2) segments.push(current.join(' '));

    return { segments, min, max, first, last };
  }, [bucketSeconds, config.scale, metric, points]);

  if (geometry.first === null || geometry.last === null || geometry.segments.length === 0) {
    return <div className="history-empty">Pas encore assez de données continues pour tracer cette période.</div>;
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
        {geometry.segments.map((segment, index) => (
          <polyline key={`${metric}-${index}`} points={segment} className="history-chart__line" />
        ))}
      </svg>
      <div className="history-axis history-axis--bottom">
        {geometry.min.toFixed(config.decimals)} {config.unit}
      </div>
      <div className="history-time-axis">
        <span>{formatDateTime(new Date(geometry.first).toISOString())}</span>
        <span>{formatDateTime(new Date(geometry.last).toISOString())}</span>
      </div>
    </div>
  );
}

function valueOrDash(value: number | null, decimals: number, unit = ''): string {
  if (value === null) return '—';
  return `${value.toFixed(decimals)}${unit ? ` ${unit}` : ''}`;
}

export default function HistoricalAnalysis() {
  const [range, setRange] = useState<TelemetryRange>('15m');
  const [metric, setMetric] = useState<MetricKey>('active_power_w');
  const [points, setPoints] = useState<TelemetrySeriesPoint[]>([]);
  const [bucketSeconds, setBucketSeconds] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
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
        setError(false);
      } else {
        setError(true);
      }
      setLoading(false);
    };

    setLoading(true);
    setError(false);
    void refresh();
    const timer = window.setInterval(() => void refresh(), range === '1m' || range === '15m' ? 5000 : 15000);
    return () => {
      mounted = false;
      window.clearInterval(timer);
    };
  }, [range]);

  const stats = useMemo(() => {
    const sampleCount = points.reduce((sum, point) => sum + Number(point.samples || 0), 0);
    const energyPoints = points
      .map((point) => ({ start: point.energy_start_wh, end: point.energy_end_wh }))
      .filter((point) => numeric(point.start) && numeric(point.end));
    const energyDeltaWh = energyPoints.length
      ? Math.max(0, (energyPoints[energyPoints.length - 1].end as number) - (energyPoints[0].start as number))
      : null;

    return {
      averagePowerW: weightedAverage(points, 'active_power_w'),
      maxPowerW: maxField(points, 'active_power_max_w', 'active_power_w'),
      minVoltageV: minField(points, 'voltage_min_v', 'voltage_v'),
      maxVoltageV: maxField(points, 'voltage_max_v', 'voltage_v'),
      maxCurrentA: maxField(points, 'current_max_a', 'current_a'),
      averagePowerFactor: weightedAverage(points, 'power_factor'),
      sampleCount,
      energyDeltaWh,
      gaps: visibleGapCount(points, bucketSeconds),
    };
  }, [bucketSeconds, points]);

  const config = METRICS[metric];
  const selectedAverageRaw = weightedAverage(points, metric);
  const selectedAverage = selectedAverageRaw === null ? null : selectedAverageRaw / config.scale;
  const hasData = points.length > 0;

  return (
    <div className="history-page">
      <section className="panel history-toolbar-panel">
        <div className="panel__title-row">
          <div>
            <span className="eyebrow">POSTGRESQL · ANALYSE OPÉRATIONNELLE</span>
            <h2>Historique des mesures AC</h2>
          </div>
          <div className="history-refresh">
            <RefreshCw size={16} className={loading ? 'spin' : ''} />
            <span>{error ? 'API indisponible' : lastRefresh ? lastRefresh.toLocaleTimeString('fr-FR') : 'chargement'}</span>
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
        <article className="history-kpi"><BarChart3 size={18} /><span>Puissance moyenne pondérée</span><strong>{valueOrDash(stats.averagePowerW === null ? null : stats.averagePowerW / 1000, 2, 'kW')}</strong></article>
        <article className="history-kpi"><Activity size={18} /><span>Puissance maximale</span><strong>{valueOrDash(stats.maxPowerW === null ? null : stats.maxPowerW / 1000, 2, 'kW')}</strong></article>
        <article className="history-kpi"><Database size={18} /><span>Variation compteur énergie</span><strong>{valueOrDash(stats.energyDeltaWh === null ? null : stats.energyDeltaWh / 1000, 3, 'kWh')}</strong></article>
        <article className="history-kpi"><Clock3 size={18} /><span>Mesures sources</span><strong>{hasData ? stats.sampleCount : '—'}</strong></article>
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
            <span className="eyebrow">COURBE AGRÉGÉE · TROUS NON RELIÉS</span>
            <h2>{config.label}</h2>
          </div>
          <div className="history-current-stat">
            <span>Moyenne pondérée</span>
            <strong>{valueOrDash(selectedAverage, config.decimals, config.unit)}</strong>
          </div>
        </div>
        {error && !hasData
          ? <div className="history-empty">Impossible de charger l’historique depuis VE-SCOPE Hub.</div>
          : <SeriesChart points={points} metric={metric} bucketSeconds={bucketSeconds} />}
        <div className="history-meta">
          <span>Fenêtre d’agrégation : {bucketSeconds ? `${bucketSeconds} s` : '—'}</span>
          <span>{points.length} points affichés · {stats.gaps} trou{stats.gaps > 1 ? 's' : ''} visible{stats.gaps > 1 ? 's' : ''}</span>
        </div>
      </section>

      <section className="history-kpis history-kpis--secondary">
        <article className="history-kpi"><span>Tension min.</span><strong>{valueOrDash(stats.minVoltageV, 1, 'V')}</strong></article>
        <article className="history-kpi"><span>Tension max.</span><strong>{valueOrDash(stats.maxVoltageV, 1, 'V')}</strong></article>
        <article className="history-kpi"><span>Courant max.</span><strong>{valueOrDash(stats.maxCurrentA, 2, 'A')}</strong></article>
        <article className="history-kpi"><span>PF moyen pondéré</span><strong>{valueOrDash(stats.averagePowerFactor, 3)}</strong></article>
      </section>

      <section className="panel history-method-note">
        <span className="eyebrow">INTERPRÉTATION</span>
        <p>
          Cette page sert au suivi opérationnel et peut inclure des données LEGACY ou VALIDATION. Les moyennes sont pondérées par le nombre de mesures sources et les interruptions temporelles ne sont plus reliées artificiellement sur la courbe. Pour le jumeau numérique, utilisez exclusivement l’export TRUSTED de la page Données.
        </p>
      </section>
    </div>
  );
}
