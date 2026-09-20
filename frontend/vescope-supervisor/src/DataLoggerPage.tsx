import { useState } from 'react';
import { Database, Download, FileSpreadsheet, HardDrive, ShieldCheck } from 'lucide-react';
import {
  eventsCsvUrl,
  sessionsCsvUrl,
  telemetryCsvUrl,
  trustedTelemetryCsvUrl,
  type CsvTelemetryRange,
} from './hubApi';

const RANGES: { value: CsvTelemetryRange; label: string; note: string }[] = [
  { value: '1h', label: '1 heure', note: 'Mesures détaillées' },
  { value: '24h', label: '24 heures', note: 'Mesures détaillées' },
  { value: '7d', label: '7 jours', note: 'Export optimisé pour une période longue' },
  { value: '30d', label: '30 jours', note: 'Export optimisé pour une période longue' },
];

export default function DataLoggerPage({ hubOnline, databaseOnline }: { hubOnline: boolean; databaseOnline: boolean }) {
  const [range, setRange] = useState<CsvTelemetryRange>('24h');
  const selected = RANGES.find((item) => item.value === range) ?? RANGES[1];
  const downloadClass = databaseOnline ? 'logger-download' : 'logger-download disabled';

  return (
    <div className="data-logger-page">
      <section className="panel logger-hero">
        <div className="panel__title-row">
          <div><span className="eyebrow">DONNÉES · EXPORTS</span><h2>Journalisation et téléchargement</h2></div>
          <HardDrive size={22} />
        </div>
        <p>Les mesures AC, les sessions de recharge et les événements sont enregistrés automatiquement. Les exports CSV sont prêts à être ouverts dans Excel ou exploités par vos outils d’analyse.</p>
        <div className="logger-status-grid">
          <div className={hubOnline ? 'logger-status ok' : 'logger-status warn'}><span>Supervision</span><strong>{hubOnline ? 'Connectée' : 'Hors ligne'}</strong></div>
          <div className={databaseOnline ? 'logger-status ok' : 'logger-status warn'}><span>Historisation</span><strong>{databaseOnline ? 'Active' : 'Indisponible'}</strong></div>
          <div className="logger-status ok"><span>Format</span><strong>CSV UTF-8</strong></div>
        </div>
      </section>

      <section className="logger-grid">
        <article className="panel logger-card">
          <div className="logger-card__icon"><Database size={22} /></div>
          <div><span className="eyebrow">MESURES AC</span><h3>Export opérationnel</h3><p>Toutes les mesures enregistrées sur la période sélectionnée pour le suivi, le diagnostic et l’analyse de fonctionnement.</p></div>
          <label className="logger-range"><span>Période à exporter</span>
            <select value={range} onChange={(event) => setRange(event.target.value as CsvTelemetryRange)}>
              {RANGES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
            <small>{selected.note}</small>
          </label>
          <a className={downloadClass} href={databaseOnline ? telemetryCsvUrl(range) : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger les mesures</a>
        </article>

        <article className="panel logger-card">
          <div className="logger-card__icon"><ShieldCheck size={22} /></div>
          <div><span className="eyebrow">MESURES VALIDÉES</span><h3>Export de référence</h3><p>Mesures approuvées pour les analyses avancées, les études de performance et l’alimentation du jumeau numérique.</p></div>
          <label className="logger-range"><span>Période à exporter</span>
            <select value={range} onChange={(event) => setRange(event.target.value as CsvTelemetryRange)}>
              {RANGES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
            <small>Une ligne par mesure validée disponible</small>
          </label>
          <a className={downloadClass} href={databaseOnline ? trustedTelemetryCsvUrl(range) : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger les mesures validées</a>
        </article>

        <article className="panel logger-card">
          <div className="logger-card__icon"><FileSpreadsheet size={22} /></div>
          <div><span className="eyebrow">SESSIONS</span><h3>Historique des recharges</h3><p>Début, fin, durée, énergie, puissances moyenne et maximale, courant maximal et facteur de puissance moyen.</p></div>
          <div className="logger-spacer" />
          <a className={downloadClass} href={databaseOnline ? sessionsCsvUrl() : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger les sessions</a>
        </article>

        <article className="panel logger-card">
          <div className="logger-card__icon"><ShieldCheck size={22} /></div>
          <div><span className="eyebrow">ÉVÉNEMENTS</span><h3>Alarmes et journal système</h3><p>Sévérité, code, message, source, valeur mesurée et seuil associé pour chaque événement enregistré.</p></div>
          <div className="logger-spacer" />
          <a className={downloadClass} href={databaseOnline ? eventsCsvUrl() : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger les événements</a>
        </article>
      </section>

      <section className="panel logger-retention">
        <div><span className="eyebrow">UTILISATION DES EXPORTS</span><h3>Deux niveaux de données</h3></div>
        <p>L’export opérationnel regroupe les mesures disponibles pour le suivi quotidien. L’export de référence contient uniquement les mesures qui ont été validées pour les analyses scientifiques et le jumeau numérique.</p>
      </section>
    </div>
  );
}
