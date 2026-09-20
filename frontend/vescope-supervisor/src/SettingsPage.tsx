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
      setMessage('Paramètres enregistrés et appliqués.');
    } catch (exception) {
      setError(exception instanceof Error ? exception.message : 'Impossible d’enregistrer les paramètres.');
    } finally {
      setSaving(false);
    }
  };

  const reset = () => {
    setThresholds(DEFAULTS);
    setMessage('Valeurs recommandées chargées. Enregistrez pour les appliquer.');
    setError('');
  };

  return (
    <div className="settings-layout">
      <section className="panel settings-intro">
        <div className="panel__title-row">
          <div>
            <span className="eyebrow">SUPERVISION</span>
            <h2>Seuils et alertes</h2>
          </div>
          <ShieldCheck size={21} />
        </div>
        <p>Configurez les seuils utilisés par la supervision pour détecter les écarts de tension, de fréquence, de facteur de puissance et de disponibilité des données.</p>
        <div className="settings-status-row">
          <span className={`settings-status ${hubOnline ? 'settings-status--ok' : 'settings-status--warn'}`}>
            <span /> Supervision {hubOnline ? 'connectée' : 'indisponible'}
          </span>
          <span className="settings-status"><Database size={14} /> {persisted ? 'Configuration enregistrée' : 'Configuration non enregistrée'}</span>
        </div>
      </section>

      <section className="settings-grid">
        <article className="panel settings-card">
          <div className="settings-card__head"><Gauge size={19} /><div><h3>Tension AC</h3><p>Plage de tension considérée comme normale.</p></div></div>
          <div className="settings-fields">
            <NumberField label="Seuil bas" value={thresholds.low_voltage_v} unit="V" min={100} max={299} step={1} onChange={(value) => update('low_voltage_v', value)} description="Une alerte est créée si la tension descend sous cette valeur." />
            <NumberField label="Seuil haut" value={thresholds.high_voltage_v} unit="V" min={101} max={300} step={1} onChange={(value) => update('high_voltage_v', value)} description="Une alerte est créée si la tension dépasse cette valeur." />
          </div>
        </article>

        <article className="panel settings-card">
          <div className="settings-card__head"><AlertTriangle size={19} /><div><h3>Facteur de puissance</h3><p>Valeur minimale admise en fonctionnement.</p></div></div>
          <div className="settings-fields settings-fields--single">
            <NumberField label="Facteur de puissance minimal" value={thresholds.low_power_factor} unit="PF" min={0.1} max={1} step={0.01} onChange={(value) => update('low_power_factor', value)} description="Une alerte est créée lorsque le facteur de puissance passe sous ce seuil." />
          </div>
        </article>

        <article className="panel settings-card">
          <div className="settings-card__head"><Gauge size={19} /><div><h3>Fréquence réseau</h3><p>Plage admissible autour de 50 Hz.</p></div></div>
          <div className="settings-fields">
            <NumberField label="Fréquence minimale" value={thresholds.low_frequency_hz} unit="Hz" min={40} max={69} step={0.1} onChange={(value) => update('low_frequency_hz', value)} description="Une alerte est créée sous cette fréquence." />
            <NumberField label="Fréquence maximale" value={thresholds.high_frequency_hz} unit="Hz" min={41} max={70} step={0.1} onChange={(value) => update('high_frequency_hz', value)} description="Une alerte est créée au-dessus de cette fréquence." />
          </div>
        </article>

        <article className="panel settings-card">
          <div className="settings-card__head"><TimerReset size={19} /><div><h3>Disponibilité des données</h3><p>Délai avant de signaler une interruption de télémétrie.</p></div></div>
          <div className="settings-fields settings-fields--single">
            <NumberField label="Délai sans nouvelle mesure" value={thresholds.stale_after_s} unit="s" min={2} max={300} step={1} onChange={(value) => update('stale_after_s', value)} description="Une alerte est créée si aucune nouvelle mesure n’est reçue pendant ce délai." />
          </div>
        </article>
      </section>

      <section className="panel settings-actions">
        <div>
          <strong>{loading ? 'Chargement de la configuration…' : dirty ? 'Modifications non enregistrées' : 'Configuration à jour'}</strong>
          <span>Les nouveaux seuils sont appliqués dès leur enregistrement.</span>
          {message && <p className="settings-message settings-message--ok">{message}</p>}
          {error && <p className="settings-message settings-message--error">{error}</p>}
        </div>
        <div className="settings-actions__buttons">
          <button type="button" className="button button--secondary" onClick={reset} disabled={saving || loading}>Valeurs recommandées</button>
          <button type="button" className="button button--primary" onClick={save} disabled={!dirty || saving || loading || !hubOnline}>
            <Save size={16} /> {saving ? 'Enregistrement…' : 'Enregistrer'}
          </button>
        </div>
      </section>
    </div>
  );
}
