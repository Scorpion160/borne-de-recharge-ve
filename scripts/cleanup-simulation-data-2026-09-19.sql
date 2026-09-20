-- VE-SCOPE - nettoyage des données de simulation avant exploitation scientifique.
-- Contexte terrain confirmé : la première recharge physique réelle a eu lieu
-- le 18/09/2026. Les données borne-01 antérieures à cette date proviennent
-- des essais de simulation/développement et ne doivent pas alimenter le
-- jumeau numérique ni les calculs de caractérisation.
--
-- Le script archive d'abord les données ciblées dans des tables dédiées,
-- puis les retire des tables de production. Il ne touche pas aux données
-- réelles acquises à partir du 18/09/2026.

BEGIN;

CREATE TABLE IF NOT EXISTS telemetry_ac_sim_archive_20260919
(LIKE telemetry_ac INCLUDING ALL);

INSERT INTO telemetry_ac_sim_archive_20260919
SELECT *
FROM telemetry_ac
WHERE device_id = 'borne-01'
  AND measured_at < TIMESTAMPTZ '2026-09-18 00:00:00+00'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS charging_sessions_sim_archive_20260919
(LIKE charging_sessions INCLUDING ALL);

INSERT INTO charging_sessions_sim_archive_20260919
SELECT *
FROM charging_sessions
WHERE device_id = 'borne-01'
  AND COALESCE(started_at, updated_at) < TIMESTAMPTZ '2026-09-18 00:00:00+00'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS events_sim_archive_20260919
(LIKE events INCLUDING ALL);

INSERT INTO events_sim_archive_20260919
SELECT *
FROM events
WHERE device_id = 'borne-01'
  AND event_at < TIMESTAMPTZ '2026-09-18 00:00:00+00'
ON CONFLICT DO NOTHING;

DELETE FROM telemetry_ac
WHERE device_id = 'borne-01'
  AND measured_at < TIMESTAMPTZ '2026-09-18 00:00:00+00';

DELETE FROM charging_sessions
WHERE device_id = 'borne-01'
  AND COALESCE(started_at, updated_at) < TIMESTAMPTZ '2026-09-18 00:00:00+00';

DELETE FROM events
WHERE device_id = 'borne-01'
  AND event_at < TIMESTAMPTZ '2026-09-18 00:00:00+00';

-- Jeu réel hérité : données physiques 0.2.11, utiles pour l'analyse terrain,
-- mais non considérées comme référence sans perte car le firmware pouvait
-- redémarrer et laisser des trous de télémétrie.
CREATE OR REPLACE VIEW telemetry_ac_real_legacy AS
SELECT *
FROM telemetry_ac
WHERE device_id = 'borne-01'
  AND measured_at >= TIMESTAMPTZ '2026-09-18 00:00:00+00'
  AND (boot_id IS NULL OR sample_id LIKE '%:legacy:%');

-- Jeu de confiance destiné au jumeau numérique : il restera vide tant que
-- le firmware durable 0.2.12-field n'aura pas été installé et validé terrain.
-- Les trames 0.2.12 portent boot_id et un sample_id non legacy.
CREATE OR REPLACE VIEW telemetry_ac_trusted AS
SELECT *
FROM telemetry_ac
WHERE device_id = 'borne-01'
  AND boot_id IS NOT NULL
  AND sample_id IS NOT NULL
  AND sample_id NOT LIKE '%:legacy:%'
  AND quality = 'GOOD';

COMMIT;

-- Contrôles post-nettoyage.
SELECT 'telemetry_production' AS dataset, COUNT(*) AS rows,
       MIN(measured_at) AS first_at, MAX(measured_at) AS last_at
FROM telemetry_ac
WHERE device_id = 'borne-01'
UNION ALL
SELECT 'telemetry_sim_archive', COUNT(*), MIN(measured_at), MAX(measured_at)
FROM telemetry_ac_sim_archive_20260919
WHERE device_id = 'borne-01';

SELECT 'sessions_production' AS dataset, COUNT(*) AS rows,
       MIN(started_at) AS first_at, MAX(started_at) AS last_at
FROM charging_sessions
WHERE device_id = 'borne-01'
UNION ALL
SELECT 'sessions_sim_archive', COUNT(*), MIN(started_at), MAX(started_at)
FROM charging_sessions_sim_archive_20260919
WHERE device_id = 'borne-01';

SELECT 'events_production' AS dataset, COUNT(*) AS rows,
       MIN(event_at) AS first_at, MAX(event_at) AS last_at
FROM events
WHERE device_id = 'borne-01'
UNION ALL
SELECT 'events_sim_archive', COUNT(*), MIN(event_at), MAX(event_at)
FROM events_sim_archive_20260919
WHERE device_id = 'borne-01';

SELECT
    (SELECT COUNT(*) FROM telemetry_ac_real_legacy) AS real_legacy_rows,
    (SELECT COUNT(*) FROM telemetry_ac_trusted) AS trusted_rows;
