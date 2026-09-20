import { useMemo, useState } from 'react';
import { Filter, Search, ShieldCheck } from 'lucide-react';
import type { AlertItem } from './types';

type SeverityFilter = 'ALL' | AlertItem['severity'];
type SourceFilter = 'ALL' | 'ELECTRICAL' | 'SYSTEM';

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('fr-FR', {
    dateStyle: 'short',
    timeStyle: 'medium',
  }).format(new Date(value));
}

export default function AlertsPage({ items, hubLive }: { items: AlertItem[]; hubLive: boolean }) {
  const [severity, setSeverity] = useState<SeverityFilter>('ALL');
  const [sourceFilter, setSourceFilter] = useState<SourceFilter>('ALL');
  const [query, setQuery] = useState('');

  const filtered = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return items.filter((item) => {
      const severityMatches = severity === 'ALL' || item.severity === severity;
      const electrical = item.source === 'pzem_ac';
      const sourceMatches = sourceFilter === 'ALL'
        || (sourceFilter === 'ELECTRICAL' && electrical)
        || (sourceFilter === 'SYSTEM' && !electrical);
      const queryMatches = !normalized
        || item.code.toLowerCase().includes(normalized)
        || item.message.toLowerCase().includes(normalized)
        || item.source?.toLowerCase().includes(normalized);
      return severityMatches && sourceMatches && queryMatches;
    });
  }, [items, query, severity, sourceFilter]);

  const counts = useMemo(() => ({
    alert: items.filter((item) => item.severity === 'ALERT' || item.severity === 'CRITICAL').length,
    warning: items.filter((item) => item.severity === 'WARNING').length,
    info: items.filter((item) => item.severity === 'INFO').length,
    electrical: items.filter((item) => item.source === 'pzem_ac').length,
  }), [items]);

  return (
    <div className="alerts-page">
      <section className="alarm-summary-grid">
        <article><span>Alertes critiques</span><strong>{counts.alert}</strong></article>
        <article><span>Avertissements</span><strong>{counts.warning}</strong></article>
        <article><span>Informations</span><strong>{counts.info}</strong></article>
        <article><span>Événements électriques</span><strong>{counts.electrical}</strong></article>
      </section>

      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">POSTGRESQL · JOURNAL DE PRODUCTION</span><h2>Alarmes et événements</h2></div>
          <ShieldCheck size={20} />
        </div>

        <div className="filter-bar">
          <label className="search-field">
            <Search size={16} />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Code, message ou source" />
          </label>
          <label className="select-with-icon">
            <Filter size={15} />
            <select value={severity} onChange={(event) => setSeverity(event.target.value as SeverityFilter)}>
              <option value="ALL">Toutes les sévérités</option>
              <option value="CRITICAL">Critique</option>
              <option value="ALERT">Alerte</option>
              <option value="WARNING">Avertissement</option>
              <option value="INFO">Information</option>
            </select>
          </label>
          <label className="select-with-icon">
            <Filter size={15} />
            <select value={sourceFilter} onChange={(event) => setSourceFilter(event.target.value as SourceFilter)}>
              <option value="ALL">Toutes les sources</option>
              <option value="ELECTRICAL">Qualité électrique</option>
              <option value="SYSTEM">Système / supervision</option>
            </select>
          </label>
          <span className="filter-count">{filtered.length} événement{filtered.length > 1 ? 's' : ''}</span>
        </div>

        <div className="event-list event-list--detailed">
          {filtered.length === 0 && <p className="note">Aucun événement ne correspond aux filtres.</p>}
          {filtered.map((item) => (
            <div className="event event--detailed" key={item.id}>
              <span className={`severity severity--${item.severity.toLowerCase()}`}>{item.severity}</span>
              <div className="event__body">
                <strong>{item.message}</strong>
                <small>{item.code} · {formatDateTime(item.timestamp)}</small>
                <div className="event__meta">
                  {item.source && <span>Source : {item.source}</span>}
                  {typeof item.value === 'number' && <span>Valeur : {item.value}</span>}
                  {typeof item.threshold === 'number' && <span>Seuil : {item.threshold}</span>}
                </div>
              </div>
            </div>
          ))}
        </div>

        <p className="note">
          {hubLive ? 'Le journal combine les événements temps réel du Hub et l’historique PostgreSQL.' : 'Le temps réel est indisponible ; les événements affichés proviennent de l’historique PostgreSQL chargé.'} Les transitions STALE du firmware legacy archivées lors du nettoyage ne sont pas réinjectées dans ce journal de production.
        </p>
      </section>
    </div>
  );
}
