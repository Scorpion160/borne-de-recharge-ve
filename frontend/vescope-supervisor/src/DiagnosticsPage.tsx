import { Database, Gauge, HardDrive, Radio, Server, Wifi } from 'lucide-react';
import type { AcTelemetry, CoreDiagnostics, CoreStatus } from './types';

function LinkBadge({ label, state, detail }: { label: string; state: 'online' | 'offline' | 'planned'; detail?: string }) {
  return (
    <div className={`link-badge link-badge--${state}`} title={detail}>
      <span className="link-badge__dot" /><span>{label}</span>{detail && <small>{detail}</small>}
    </div>
  );
}

function boolLabel(value: boolean | undefined, yes = 'Oui', no = 'Non'): string {
  if (value === undefined) return '—';
  return value ? yes : no;
}

function formatUptime(seconds: number | undefined): string {
  if (seconds === undefined) return '—';
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (days > 0) return `${days} j ${hours} h ${minutes} min`;
  if (hours > 0) return `${hours} h ${minutes} min`;
  return `${minutes} min`;
}

function bytesLabel(bytes: number | undefined): string {
  if (bytes === undefined) return '—';
  if (bytes < 1024) return `${bytes} o`;
  return `${(bytes / 1024).toFixed(1)} KiB`;
}

export default function DiagnosticsPage({
  telemetry,
  status,
  diagnostics,
  hubLive,
  hubOnline,
  databaseOnline,
}: {
  telemetry: AcTelemetry | null;
  status: CoreStatus | null;
  diagnostics: CoreDiagnostics | null;
  hubLive: boolean;
  hubOnline: boolean;
  databaseOnline: boolean;
}) {
  const pzemOnline = status?.pzem_online ?? diagnostics?.pzem_online ?? Boolean(telemetry);
  const wifiOnline = status?.transport_wifi ?? diagnostics?.wifi_connected;
  const firmware = diagnostics?.firmware ?? status?.firmware ?? '—';
  const durableAvailable = diagnostics?.durable_store_ok !== undefined
    || diagnostics?.durable_pending_telemetry !== undefined
    || status?.durable_pending !== undefined;

  return (
    <div className="two-columns">
      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">VE-SCOPE CORE</span><h2>Diagnostic système réel</h2></div>
          <Gauge size={20} />
        </div>
        <dl className="detail-list">
          <div><dt>Firmware</dt><dd>{firmware}</dd></div>
          <div><dt>Boot ID</dt><dd>{diagnostics?.boot_id ?? telemetry?.boot_id ?? '—'}</dd></div>
          <div><dt>Uptime</dt><dd>{formatUptime(diagnostics?.uptime_s)}</dd></div>
          <div><dt>Mémoire libre</dt><dd>{diagnostics?.free_heap_bytes !== undefined ? `${Math.round(diagnostics.free_heap_bytes / 1024)} KiB` : '—'}</dd></div>
          <div><dt>Dernière séquence</dt><dd>{telemetry ? `#${telemetry.sequence}` : '—'}</dd></div>
          <div><dt>Sample ID</dt><dd>{telemetry?.sample_id ?? 'Legacy / indisponible'}</dd></div>
          <div><dt>Qualité donnée</dt><dd>{telemetry ? (hubLive ? telemetry.quality : 'STALE') : 'UNAVAILABLE'}</dd></div>
          <div><dt>Horodatage mesure</dt><dd>{telemetry ? new Date(telemetry.timestamp).toLocaleString('fr-FR') : '—'}</dd></div>
        </dl>
      </section>

      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">RÉSEAU</span><h2>Communications</h2></div>
          <Server size={20} />
        </div>
        <div className="links-stack">
          <LinkBadge label="VE-SCOPE Hub" state={hubOnline ? 'online' : 'offline'} detail={hubOnline ? 'WebSocket connecté' : 'Hors ligne'} />
          <LinkBadge label="PostgreSQL" state={databaseOnline ? 'online' : 'offline'} detail={databaseOnline ? 'Historisation active' : 'Indisponible'} />
          <LinkBadge label="Wi-Fi borne" state={wifiOnline ? 'online' : 'offline'} detail={diagnostics?.wifi_rssi_dbm !== undefined ? `${diagnostics.wifi_rssi_dbm} dBm` : undefined} />
          <LinkBadge label="PZEM" state={pzemOnline ? 'online' : 'offline'} detail={pzemOnline ? 'Acquisition réelle' : 'Aucune mesure récente'} />
          <LinkBadge label="BLE" state={diagnostics ? 'online' : 'planned'} detail={diagnostics ? (diagnostics.ble_connected ? 'Client connecté' : 'Service disponible') : 'Disponible avec 0.2.12'} />
        </div>
        <dl className="detail-list">
          <div><dt>Transport cloud</dt><dd>{diagnostics?.cloud_transport ?? status?.cloud_transport ?? '—'}</dd></div>
          <div><dt>Adresse Wi-Fi</dt><dd>{diagnostics?.wifi_ip || '—'}</dd></div>
          <div><dt>RSSI</dt><dd>{diagnostics?.wifi_rssi_dbm !== undefined ? `${diagnostics.wifi_rssi_dbm} dBm` : '—'}</dd></div>
          <div><dt>MQTT TLS</dt><dd>{boolLabel(diagnostics?.mqtt_connected, 'Connecté', 'Non connecté')}</dd></div>
          <div><dt>Fallback HTTPS</dt><dd>{boolLabel(diagnostics?.https_fallback_ok, 'Opérationnel', 'Non confirmé')}</dd></div>
          <div><dt>Portail captif</dt><dd>{status?.captive_portal_enabled ?? diagnostics?.captive_portal_enabled ? boolLabel(status?.captive_portal_authenticated ?? diagnostics?.captive_portal_authenticated, 'Authentifié', 'Non authentifié') : 'Désactivé'}</dd></div>
        </dl>
      </section>

      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">ACQUISITION</span><h2>PZEM-004T</h2></div>
          <Radio size={20} />
        </div>
        <dl className="detail-list">
          <div><dt>État PZEM</dt><dd>{pzemOnline ? 'EN LIGNE' : 'INDISPONIBLE'}</dd></div>
          <div><dt>Lectures OK</dt><dd>{diagnostics?.pzem_reads_ok ?? '—'}</dd></div>
          <div><dt>Erreurs cumulées</dt><dd>{diagnostics?.pzem_errors ?? '—'}</dd></div>
          <div><dt>Erreurs consécutives</dt><dd>{diagnostics?.pzem_consecutive_errors ?? '—'}</dd></div>
          <div><dt>Dernière erreur</dt><dd>{diagnostics?.pzem_last_error || 'Aucune erreur remontée'}</dd></div>
          <div><dt>Tension instantanée</dt><dd>{telemetry ? `${telemetry.voltage_v.toFixed(1)} V` : '—'}</dd></div>
          <div><dt>Courant instantané</dt><dd>{telemetry ? `${telemetry.current_a.toFixed(3)} A` : '—'}</dd></div>
        </dl>
      </section>

      <section className="panel">
        <div className="panel__title-row">
          <div><span className="eyebrow">DURABILITÉ</span><h2>File locale et persistance</h2></div>
          <HardDrive size={20} />
        </div>
        {durableAvailable ? (
          <dl className="detail-list">
            <div><dt>Stockage durable</dt><dd>{boolLabel(diagnostics?.durable_store_ok, 'OK', 'ERREUR')}</dd></div>
            <div><dt>Erreur file</dt><dd>{boolLabel(diagnostics?.durable_queue_error, 'Oui', 'Non')}</dd></div>
            <div><dt>Télémétries en attente</dt><dd>{diagnostics?.durable_pending_telemetry ?? status?.durable_pending ?? '—'}</dd></div>
            <div><dt>Volume en attente</dt><dd>{bytesLabel(diagnostics?.durable_pending_bytes)}</dd></div>
            <div><dt>Résumés session en attente</dt><dd>{diagnostics?.durable_pending_summaries ?? '—'}</dd></div>
            <div><dt>HTTPS succès</dt><dd>{diagnostics?.https_publish_ok ?? '—'}</dd></div>
            <div><dt>HTTPS erreurs</dt><dd>{diagnostics?.https_publish_errors ?? '—'}</dd></div>
          </dl>
        ) : (
          <p className="note">Ces indicateurs apparaîtront après installation de VE-SCOPE Core 0.2.12-field.</p>
        )}
        <div className="links-stack">
          <LinkBadge label="Stockage PostgreSQL" state={databaseOnline ? 'online' : 'offline'} detail="Persistance serveur" />
          <LinkBadge label="Buffer local Core" state={durableAvailable ? (diagnostics?.durable_store_ok === false ? 'offline' : 'online') : 'planned'} detail={durableAvailable ? 'File SPIFFS persistante' : 'Disponible avec 0.2.12'} />
        </div>
      </section>
    </div>
  );
}
