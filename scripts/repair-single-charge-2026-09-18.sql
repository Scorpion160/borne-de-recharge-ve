-- VE-SCOPE - réparation conservative de la recharge réelle du 18/09/2026.
-- Contexte confirmé terrain : une seule recharge physique, fragmentée en trois
-- sessions par des redémarrages du Core 0.2.11.
--
-- Ce script sauvegarde d'abord les trois lignes d'origine, puis consolide la
-- recharge sous le premier session_id. Il ne touche PAS aux données simulateur.

BEGIN;

CREATE TABLE IF NOT EXISTS charging_sessions_backup_20260918 AS
SELECT * FROM charging_sessions WITH NO DATA;

INSERT INTO charging_sessions_backup_20260918
SELECT s.*
FROM charging_sessions s
WHERE s.session_id IN (
    'VE01-20260918-115811',
    'VE01-20260918-120254',
    'VE01-20260918-120617'
)
AND NOT EXISTS (
    SELECT 1
    FROM charging_sessions_backup_20260918 b
    WHERE b.session_id = s.session_id
);

UPDATE charging_sessions
SET
    state = 'COMPLETE',
    started_at = TIMESTAMPTZ '2026-09-18 11:58:11+00',
    ended_at = TIMESTAMPTZ '2026-09-18 12:14:29+00',
    duration_s = 978,
    energy_wh = 773.0,
    average_power_w = 2845.398773006135,
    max_power_w = 3497.7,
    max_current_a = 14.898,
    average_power_factor = (
        SELECT SUM(COALESCE(average_power_factor, 0) * COALESCE(duration_s, 0))
               / NULLIF(SUM(COALESCE(duration_s, 0)), 0)
        FROM charging_sessions_backup_20260918
        WHERE session_id IN (
            'VE01-20260918-115811',
            'VE01-20260918-120254',
            'VE01-20260918-120617'
        )
    ),
    end_reason = 'RECOVERED_FROM_REBOOT_FRAGMENTS',
    updated_at = NOW(),
    raw = jsonb_build_object(
        'schema', 1,
        'device_id', 'borne-01',
        'session_id', 'VE01-20260918-115811',
        'state', 'COMPLETE',
        'started_at', '2026-09-18T11:58:11Z',
        'ended_at', '2026-09-18T12:14:29Z',
        'duration_s', 978,
        'energy_wh', 773.0,
        'average_power_w', 2845.398773006135,
        'max_power_w', 3497.7,
        'max_current_a', 14.898,
        'repair', true,
        'repair_reason', 'single physical charge fragmented by Core reboots',
        'source_session_ids', jsonb_build_array(
            'VE01-20260918-115811',
            'VE01-20260918-120254',
            'VE01-20260918-120617'
        )
    )
WHERE session_id = 'VE01-20260918-115811';

DELETE FROM charging_sessions
WHERE session_id IN (
    'VE01-20260918-120254',
    'VE01-20260918-120617'
);

COMMIT;

-- Contrôle attendu : une seule session réelle du 18/09/2026.
SELECT session_id, state, started_at, ended_at, duration_s, energy_wh,
       average_power_w, max_power_w, max_current_a, average_power_factor,
       end_reason
FROM charging_sessions
WHERE started_at >= TIMESTAMPTZ '2026-09-18 00:00:00+00'
ORDER BY started_at;
