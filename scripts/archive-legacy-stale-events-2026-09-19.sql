-- VE-SCOPE - archivage des événements de staleness générés pendant la phase legacy 0.2.11.
-- Ces événements sont réels du point de vue communication, mais ils ne décrivent
-- pas un phénomène électrique de la borne. Avec le seuil legacy de 20 s et les
-- transmissions HTTPS irrégulières, ils produisent un volume très important de
-- transitions STALE / RECOVERED qui pollue l'historique de production.
--
-- Le script archive d'abord toutes les lignes ciblées existantes au moment de
-- l'exécution, puis les retire de la table events. Les événements PZEM (tension,
-- fréquence, facteur de puissance, qualité) ne sont pas touchés.

BEGIN;

CREATE TABLE IF NOT EXISTS events_legacy_stale_archive_20260919
(LIKE events INCLUDING ALL);

INSERT INTO events_legacy_stale_archive_20260919
SELECT *
FROM events
WHERE device_id = 'borne-01'
  AND source = 'vescope_hub'
  AND code IN ('AC_TELEMETRY_STALE', 'AC_TELEMETRY_STALE_RECOVERED')
ON CONFLICT DO NOTHING;

DELETE FROM events
WHERE device_id = 'borne-01'
  AND source = 'vescope_hub'
  AND code IN ('AC_TELEMETRY_STALE', 'AC_TELEMETRY_STALE_RECOVERED');

CREATE OR REPLACE VIEW events_electrical_quality AS
SELECT *
FROM events
WHERE device_id = 'borne-01'
  AND source = 'pzem_ac';

COMMIT;

SELECT 'legacy_stale_archive' AS dataset,
       COUNT(*) AS rows,
       MIN(event_at) AS first_at,
       MAX(event_at) AS last_at
FROM events_legacy_stale_archive_20260919
WHERE device_id = 'borne-01';

SELECT code, severity, source, COUNT(*) AS occurrences,
       MIN(event_at) AS first_at, MAX(event_at) AS last_at
FROM events
WHERE device_id = 'borne-01'
GROUP BY code, severity, source
ORDER BY occurrences DESC, code;

SELECT COUNT(*) AS electrical_quality_rows
FROM events_electrical_quality;
