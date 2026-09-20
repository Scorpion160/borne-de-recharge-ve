import { useEffect, useState } from 'react';
import { AlertTriangle, Database, Gauge, Save, ShieldCheck, TimerReset } from 'lucide-react';
import {
  fetchDeviceSettings,
  saveDeviceSettings,
  type AlarmThresholds,
} from './hubApi';

const DEFAULTS: AlarmThresholds = {
  low_voltage_v: 207,
  high_voltage_v: 253,
  low_power_factor: 0.9,
  low_frequency_hz: 49,
  high_frequency_hz: 51,
  stale_after_s: 180,
};

function NumberField({
  label,
  value,
  unit,
  min,
  max,
  step,
  onChange,
  description,
}: {
  label: string;
  value: number;
  unit: string;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
  description: string;
}) {
  return (
    <label className="settings-field">
      <span className="settings-field__label">{label}</span>
      <span className="settings-field__control">
        <input
          type="number"
          value={value}
          min={min}
          max={max}
          step={step}
          onChange={(event) => onChange(Number(event.target.value))}
        />
        <strong>{unit}</strong>
      </span>
      <small>{description}</small>
    </label>
  );
}

export default function SettingsPage({ hubOnline }: { hubOnline: boolean }) {
  const [thresholds, setThresholds] = useState<AlarmThresholds>(DEFAULTS);
  const [saved, setSaved] = useState<AlarmThresholds>(DEFAULTS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [persisted, setPersisted] = useState(false);

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      setLoading(true);
      const result = await fetchDeviceSettings();
      if (!mounted) return;
      if (result) {
        setThresholds(result.alarm_thresholds);
        setSaved(result.alarm_thresholds);
        setPersisted(Boolean(result.persisted));
      }
      setLoading(false);
    };
    void load();
    return () => { mounted = false; };
  }, []);

  const dirty = JSON.stringify(thresholds) !== JSON.stringify(saved);

  const update = (key: keyof AlarmThresholds, value: number) => {
    setThresholds((current) => ({ ...current, [key]: value }));
    setMessage('');
    setError('');
  };

  const validate = (): string | null => {
    if (thresholds.low_voltage_v >= thresholds.high_voltage_v) return 'La tension minimale doit être inférieure à la tension maximale.';
    if (thresholds.low_frequency_hz >= thresholds.high_frequency_hz) return 'La fréquence minimale doit être inférieure à la fréquence maximale.';
    return null;
  };

  const save = async () => {
    const validation = validate();
    if (validation) {
      setError(validation);
      return;
    }
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const result = await saveDeviceSettings(thresholds);
      setThresholds(result.alarm_thresholds);
      setSaved(result.alarm_thresholds);
      setPersisted(true);
      setMessage('Seuils enregistrés dans VE-SCOPE Hub et PostgreSQL. Ils sont appliqués immédiatement.');
    } catch (exception) {
      setError(exception instanceof Error ? exception.message : 'Impossible d’enregistrer les paramètres.');
    } finally {
      setSaving(false);
    }
  };

  const reset = () => {
    setThresholds(DEFAULTS);
    setMessage('Profil terrain chargé. Cliquez sur Enregistrer pour l’appliquer.');
    setError('');
  };

  return (
    <div className="settings-layout">
      <section className="panel settings-intro">
        <div className="panel__title-row">
          <div>
            <span className="eyebrow">VE-SCOPE HUB · CONFIGURATION</span>
            <h2>Paramètres de supervision</h2>
          </div>
          <ShieldCheck size={21} />
        </div>
        <p>
          Ces valeurs pilotent le moteur d’alarmes du Hub. Elles ne remplacent pas les protections électriques matérielles de la borne,
          du chargeur ou du BMS.
        </p>
        <div className="settings-status-row">
          <span className={`settings-status ${hubOnline ? 'settings-status--ok' : 'settings-status--warn'}`}>
            <span /> Hub {hubOnline ? 'connecté' : 'indisponible'}
          </span>
          <span className="settings-status"><Database size={14} /> {persisted ? 'Configuration persistée' : 'Valeurs locales de secours'}</span>
        </div>
      </section>

      <section className="settings-grid">
        <article className="panel settings-card">
          <div className="settings-card__head"><Gauge size={19} /><div><h3>Tension AC</h3><p>Surveillance de la tension efficace mesurée par le PZEM.</p></div></div>
          <div className="settings-fields">
            <NumberField label="Seuil bas" value={thresholds.low_voltage_v} unit="V" min={100} max={299} step={1} onChange={(value) => update('low_voltage_v', value)} description="Déclenche AC_LOW_VOLTAGE en dessous de cette valeur." />
            <NumberField label="Seuil haut" value={thresholds.high_voltage_v} unit="V" min={101} max={300} step={1} onChange={(value) => update('high_voltage_v', value)} description="Déclenche AC_HIGH_VOLTAGE au-dessus de cette valeur." />
          </div>
        </article>

        <article className="panel settings-card">
          <div className="settings-card__head"><AlertTriangle size={19} /><div><h3>Qualité de puissance</h3><p>Seuil minimal du facteur de puissance.</p></div></div>
          <div className="settings-fields settings-fields--single">
            <NumberField label="Facteur de puissance minimal" value={thresholds.low_power_factor} unit="PF" min={0.1} max={1} step={0.01} onChange={(value) => update('low_power_factor', value)} description="Déclenche AC_LOW_POWER_FACTOR lorsque le PF est inférieur au seuil." />
          </div>
        </article>

        <article className="panel settings-card">
          <div className="settings-card__head"><Gauge size={19} /><div><h3>Fréquence réseau</h3><p>Plage admissible autour de 50 Hz.</p></div></div>
          <div className="settings-fields">
            <NumberField label="Fréquence minimale" value={thresholds.low_frequency_hz} unit="Hz" min={40} max={69} step={0.1} onChange={(value) => update('low_frequency_hz', value)} description="Limite basse de surveillance de la fréquence." />
            <NumberField label="Fréquence maximale" value={thresholds.high_frequency_hz} unit="Hz" min={41} max={70} step={0.1} onChange={(value) => update('high_frequency_hz', value)} description="Limite haute de surveillance de la fréquence." />
          </div>
        </article>

        <article className="panel settings-card">
          <div className="settings-card__head"><TimerReset size={19} /><div><h3>Disponibilité des données</h3><p>Délai avant de considérer la télémétrie comme perdue.</p></div></div>
          <div className="settings-fields settings-fields--single">
            <NumberField label="Perte de télémétrie" value={thresholds.stale_after_s} unit="s" min={2} max={300} step={1} onChange={(value) => update('stale_after_s', value)} description="Déclenche AC_TELEMETRY_STALE lorsqu’aucune nouvelle donnée n’arrive dans ce délai. Le profil terrain actuel utilise 180 s tant que 0.2.12 n’est pas validé." />
          </div>
        </article>
      </section>

      <section className="panel settings-actions">
        <div>
          <strong>{loading ? 'Chargement de la configuration…' : dirty ? 'Modifications non enregistrées' : 'Configuration à jour'}</strong>
          <span>Les modifications sont appliquées par VE-SCOPE Hub dès leur enregistrement.</span>
          {message && <p className="settings-message settings-message--ok">{message}</p>}
          {error && <p className="settings-message settings-message--error">{error}</p>}
        </div>
        <div className="settings-actions__buttons">
          <button type="button" className="button button--secondary" onClick={reset} disabled={saving || loading}>Profil terrain</button>
          <button type="button" className="button button--primary" onClick={save} disabled={!dirty || saving || loading || !hubOnline}>
            <Save size={16} /> {saving ? 'Enregistrement…' : 'Enregistrer'}
          </button>
        </div>
      </section>
    </div>
  );
}
