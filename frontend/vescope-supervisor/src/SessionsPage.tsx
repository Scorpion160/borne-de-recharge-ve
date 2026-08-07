import { useMemo, useState } from 'react';
import { CalendarDays, Clock3, Database, Gauge, Search, Zap } from 'lucide-react';
import type { StoredSession } from './hubApi';
import type { LiveSession, StationState } from './types';

function formatDuration(seconds: number | null): string {
  const value = seconds ?? 0;
  const h = Math.floor(value / 3600);
  const m = Math.floor((value % 3600) / 60);
  const s = value % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function stateLabel(state: StationState): string {
  const labels: Record<StationState, string> = {
    OFFLINE: 'Hors ligne',
    IDLE: 'Disponible',
    SESSION_STARTING: 'Démarrage',
    CHARGING: 'En charge',
    CHARGING_LIMITED: 'Charge limitée',
    FINISHING: 'Fin de charge',
    COMPLETE: 'Terminée',
    INTERRUPTED: 'Interrompue',
    FAULT: 'Défaut',
    MAINTENANCE: 'Maintenance',
  };
  return labels[state];
}

function dateTime(value: string | null): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat('fr-FR', {
    dateStyle: 'short',
    timeStyle: 'medium',
  }).format(new Date(value));
}

function liveAsStored(session: LiveSession): StoredSession {
  return {
    session_id: session.session_id,
    state: session.state,
    started_at: session.started_at,
    ended_at: null,
    duration_s: session.duration_s,
    energy_wh: session.energy_wh,
    average_power_w: session.average_power_w,
    max_power_w: session.max_power_w,
    max_current_a: session.max_current_a,
    average_power_factor: session.average_power_factor,
    end_reason: null,
    updated_at: new Date().toISOString(),
  };
}

export default function SessionsPage({
  session,
  stored,
  hubLive,
}: {
  session: LiveSession;
  stored: StoredSession[];
  hubLive: boolean;
}) {
  const [stateFilter, setStateFilter] = useState<'ALL' | StationState>('ALL');
  const [query, setQuery] = useState('');
  const rows = useMemo(() => {
    const source = stored.length > 0 ? stored : [liveAsStored(session)];
    return source.filter((item) => {
      const stateMatches = stateFilter === 'ALL' || item.state === stateFilter;
      const queryMatches = item.session_id.toLowerCase().includes(query.trim().toLowerCase());
      return stateMatches && queryMatches;
    });
  }, [query, session, stateFilter, stored]);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = rows.find((item) => item.session_id === selectedId) ?? rows[0] ?? null;

  return (
    <div className="sessions-page">
      <section className="panel sessions-toolbar">
        <div className="panel__title-row">
          <div><span className="eyebrow">POSTGRESQL · HISTORIQUE</span><h2>Sessions de recharge</h2></div>
          <span className="quality-badge">{hubLive ? 'HUB' : 'LOCAL'}</span>
        </div>
        <div className="filter-bar">
          <label className="search-field">
            <Search size={16} />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Rechercher une session" />
          </label>
          <select value={stateFilter} onChange={(event) => setStateFilter(event.target.value as 'ALL' | StationState)}>
            <option value="ALL">Tous les états</option>
            <option value="CHARGING">En charge</option>
            <option value="COMPLETE">Terminées</option>
            <option value="INTERRUPTED">Interrompues</option>
            <option value="FAULT">Défaut</option>
          </select>
          <span className="filter-count">{rows.length} session{rows.length > 1 ? 's' : ''}</span>
        </div>
      </section>

      <section className="session-layout">
        <div className="panel session-list-panel">
          <div className="session-table session-table--interactive">
            <div className="session-table__head"><span>Session</span><span>Durée</span><span>Énergie</span><span>P max</span><span>État</span></div>
            {rows.map((item) => (
              <button
                type="button"
                key={item.session_id}
                className={`session-table__row ${selected?.session_id === item.session_id ? 'selected' : ''}`}
                onClick={() => setSelectedId(item.session_id)}
              >
                <span>{item.session_id}</span>
                <span>{formatDuration(item.duration_s)}</span>
                <span>{((item.energy_wh ?? 0) / 1000).toFixed(3)} kWh</span>
                <span>{((item.max_power_w ?? 0) / 1000).toFixed(2)} kW</span>
                <span className={item.state === 'CHARGING' ? 'status-text' : undefined}>{stateLabel(item.state)}</span>
              </button>
            ))}
            {rows.length === 0 && <p className="note">Aucune session ne correspond aux filtres.</p>}
          </div>
        </div>

        <aside className="panel session-detail-panel">
          <div className="panel__title-row">
            <div><span className="eyebrow">DÉTAIL SESSION</span><h2>{selected?.session_id ?? 'Aucune session'}</h2></div>
            <CalendarDays size={20} />
          </div>
          {selected ? (
            <>
              <div className="session-detail-state">{stateLabel(selected.state)}</div>
              <div className="session-detail-grid">
                <div><Clock3 size={16} /><span>Début</span><strong>{dateTime(selected.started_at)}</strong></div>
                <div><Clock3 size={16} /><span>Fin</span><strong>{dateTime(selected.ended_at)}</strong></div>
                <div><Database size={16} /><span>Énergie</span><strong>{((selected.energy_wh ?? 0) / 1000).toFixed(3)} kWh</strong></div>
                <div><Zap size={16} /><span>Puissance moy.</span><strong>{((selected.average_power_w ?? 0) / 1000).toFixed(2)} kW</strong></div>
                <div><Zap size={16} /><span>Puissance max.</span><strong>{((selected.max_power_w ?? 0) / 1000).toFixed(2)} kW</strong></div>
                <div><Gauge size={16} /><span>Courant max.</span><strong>{(selected.max_current_a ?? 0).toFixed(2)} A</strong></div>
                <div><Gauge size={16} /><span>PF moyen</span><strong>{(selected.average_power_factor ?? 0).toFixed(3)}</strong></div>
                <div><Clock3 size={16} /><span>Durée</span><strong>{formatDuration(selected.duration_s)}</strong></div>
              </div>
              {selected.end_reason && <p className="note">Cause de fin : {selected.end_reason}</p>}
            </>
          ) : <p className="note">Sélectionnez une session pour afficher son détail.</p>}
        </aside>
      </section>
    </div>
  );
}
