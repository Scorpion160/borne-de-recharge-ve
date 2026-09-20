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
  { value: '1h', label: '1 heure', note: 'Mesures brutes' },
  { value: '24h', label: '24 heures', note: 'Mesures brutes' },
  { value: '7d', label: '7 jours', note: 'Agrégation 1 minute pour l’export opérationnel' },
  { value: '30d', label: '30 jours', note: 'Agrégation 5 minutes pour l’export opérationnel' },
];

export default function DataLoggerPage({ hubOnline, databaseOnline }: { hubOnline: boolean; databaseOnline: boolean }) {
  const [range, setRange] = useState<CsvTelemetryRange>('24h');
  const selected = RANGES.find((item) => item.value === range) ?? RANGES[1];
  const downloadClass = databaseOnline ? 'logger-download' : 'logger-download disabled';

  return (
    <div className="data-logger-page">
      <section className="panel logger-hero">
        <div className="panel__title-row">
          <div><span className="eyebrow">DATA LOGGER · POSTGRESQL</span><h2>Journalisation et export des données</h2></div>
          <HardDrive size={22} />
        </div>
        <p>VE-SCOPE Hub enregistre automatiquement les mesures AC, les sessions de recharge et les événements. Les fichiers CSV sont encodés en UTF-8 et utilisent le séparateur point-virgule pour une ouverture directe dans Excel.</p>
        <div className="logger-status-grid">
          <div className={hubOnline ? 'logger-status ok' : 'logger-status warn'}><span>VE-SCOPE Hub</span><strong>{hubOnline ? 'Connecté' : 'Hors ligne'}</strong></div>
          <div className={databaseOnline ? 'logger-status ok' : 'logger-status warn'}><span>PostgreSQL</span><strong>{databaseOnline ? 'Journalisation active' : 'Indisponible'}</strong></div>
          <div className="logger-status ok"><span>Format</span><strong>CSV UTF-8</strong></div>
        </div>
      </section>

      <section className="logger-grid">
        <article className="panel logger-card">
          <div className="logger-card__icon"><Database size={22} /></div>
          <div><span className="eyebrow">TÉLÉMÉTRIE AC · OPÉRATIONNEL</span><h3>Mesures électriques complètes</h3><p>Export de travail contenant les données conservées dans PostgreSQL, y compris les données legacy et de validation selon la période.</p></div>
          <label className="logger-range"><span>Période à exporter</span>
            <select value={range} onChange={(event) => setRange(event.target.value as CsvTelemetryRange)}>
              {RANGES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
            <small>{selected.note}</small>
          </label>
          <a className={downloadClass} href={databaseOnline ? telemetryCsvUrl(range) : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger l’export opérationnel</a>
        </article>

        <article className="panel logger-card">
          <div className="logger-card__icon"><ShieldCheck size={22} /></div>
          <div><span className="eyebrow">TÉLÉMÉTRIE AC · TRUSTED</span><h3>Dataset scientifique validé</h3><p>Uniquement les mesures GOOD provenant de boot_id explicitement validés. Cet export est la source prévue pour le jumeau numérique.</p></div>
          <label className="logger-range"><span>Période à exporter</span>
            <select value={range} onChange={(event) => setRange(event.target.value as CsvTelemetryRange)}>
              {RANGES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
            <small>Aucune agrégation : une ligne par mesure TRUSTED</small>
          </label>
          <a className={downloadClass} href={databaseOnline ? trustedTelemetryCsvUrl(range) : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger le dataset TRUSTED</a>
        </article>

        <article className="panel logger-card">
          <div className="logger-card__icon"><FileSpreadsheet size={22} /></div>
          <div><span className="eyebrow">SESSIONS</span><h3>Historique des recharges</h3><p>Début, fin, durée, énergie, puissances moyenne/maximale, courant maximal et PF moyen.</p></div>
          <div className="logger-spacer" />
          <a className={downloadClass} href={databaseOnline ? sessionsCsvUrl() : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger les sessions CSV</a>
        </article>

        <article className="panel logger-card">
          <div className="logger-card__icon"><ShieldCheck size={22} /></div>
          <div><span className="eyebrow">ÉVÉNEMENTS</span><h3>Alarmes et journal système</h3><p>Sévérité, code, message, source, valeur ayant déclenché l'événement et seuil associé.</p></div>
          <div className="logger-spacer" />
          <a className={downloadClass} href={databaseOnline ? eventsCsvUrl() : undefined} aria-disabled={!databaseOnline} download><Download size={18} />Télécharger les événements CSV</a>
        </article>
      </section>

      <section className="panel logger-retention">
        <div><span className="eyebrow">POLITIQUE DE DONNÉES</span><h3>LEGACY, VALIDATION et TRUSTED sont séparés</h3></div>
        <p>Les mesures physiques anciennes restent disponibles pour le diagnostic mais ne sont pas utilisées automatiquement comme référence scientifique. Les nouvelles mesures dotées d’un boot_id restent en VALIDATION jusqu’à approbation explicite après les essais terrain. Seules les mesures TRUSTED doivent alimenter le jumeau numérique.</p>
      </section>
    </div>
  );
}
