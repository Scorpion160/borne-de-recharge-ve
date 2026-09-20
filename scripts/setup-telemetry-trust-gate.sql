-- VE-SCOPE - frontière explicite LEGACY / VALIDATION / TRUSTED pour les données AC.
--
-- Objectif : empêcher qu'une trame physique soit considérée comme donnée de
-- référence du jumeau numérique uniquement parce qu'elle possède boot_id,
-- sample_id et quality='GOOD'.
--
-- Principe :
--   * LEGACY     : anciennes trames physiques sans boot_id / sample_id durable.
--   * VALIDATION : nouvelles trames non-legacy, mais boot_id pas encore validé.
--   * TRUSTED    : boot_id explicitement approuvé après essais terrain.
--   * REJECTED   : boot_id explicitement exclu.
--
-- Aucun boot_id n'est promu automatiquement vers TRUSTED.

BEGIN;

CREATE TABLE IF NOT EXISTS telemetry_trust_registry (
    device_id TEXT NOT NULL,
    boot_id BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'VALIDATION'
        CHECK (status IN ('VALIDATION', 'TRUSTED', 'REJECTED')),
    firmware TEXT,
    validation_note TEXT,
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (device_id, boot_id)
);

CREATE INDEX IF NOT EXISTS idx_telemetry_trust_registry_status
ON telemetry_trust_registry(device_id, status, boot_id);

-- Vue legacy : données physiques historiques utiles pour diagnostic et
-- caractérisation prudente, mais non admissibles comme ground truth dynamique.
CREATE OR REPLACE VIEW telemetry_ac_real_legacy AS
SELECT t.*
FROM telemetry_ac t
WHERE t.device_id = 'borne-01'
  AND (
      t.boot_id IS NULL
      OR t.sample_id IS NULL
      OR t.sample_id LIKE '%:legacy:%'
  );

-- Vue validation : toutes les trames non-legacy qui ne sont pas explicitement
-- TRUSTED ou REJECTED. Un nouveau boot_id arrive donc ici automatiquement.
CREATE OR REPLACE VIEW telemetry_ac_validation AS
SELECT t.*
FROM telemetry_ac t
LEFT JOIN telemetry_trust_registry r
  ON r.device_id = t.device_id
 AND r.boot_id = t.boot_id
WHERE t.device_id = 'borne-01'
  AND t.boot_id IS NOT NULL
  AND t.sample_id IS NOT NULL
  AND t.sample_id NOT LIKE '%:legacy:%'
  AND COALESCE(r.status, 'VALIDATION') = 'VALIDATION';

-- Vue trusted : seulement les boot_id explicitement approuvés ET les mesures
-- dont la qualité est GOOD. C'est la source destinée au jumeau numérique.
CREATE OR REPLACE VIEW telemetry_ac_trusted AS
SELECT t.*
FROM telemetry_ac t
JOIN telemetry_trust_registry r
  ON r.device_id = t.device_id
 AND r.boot_id = t.boot_id
WHERE t.device_id = 'borne-01'
  AND r.status = 'TRUSTED'
  AND t.sample_id IS NOT NULL
  AND t.sample_id NOT LIKE '%:legacy:%'
  AND t.quality = 'GOOD';

CREATE OR REPLACE VIEW telemetry_ac_rejected AS
SELECT t.*
FROM telemetry_ac t
JOIN telemetry_trust_registry r
  ON r.device_id = t.device_id
 AND r.boot_id = t.boot_id
WHERE t.device_id = 'borne-01'
  AND r.status = 'REJECTED';

-- Vue synthétique pour audit et export scientifique.
CREATE OR REPLACE VIEW telemetry_ac_classified AS
SELECT
    t.*,
    CASE
        WHEN t.boot_id IS NULL
          OR t.sample_id IS NULL
          OR t.sample_id LIKE '%:legacy:%'
            THEN 'LEGACY'
        WHEN r.status = 'TRUSTED' THEN 'TRUSTED'
        WHEN r.status = 'REJECTED' THEN 'REJECTED'
        ELSE 'VALIDATION'
    END AS trust_state
FROM telemetry_ac t
LEFT JOIN telemetry_trust_registry r
  ON r.device_id = t.device_id
 AND r.boot_id = t.boot_id
WHERE t.device_id = 'borne-01';

COMMIT;

-- Contrôle immédiat.
SELECT trust_state, COUNT(*) AS rows
FROM telemetry_ac_classified
GROUP BY trust_state
ORDER BY trust_state;

SELECT COUNT(*) AS trusted_rows FROM telemetry_ac_trusted;
SELECT COUNT(*) AS validation_rows FROM telemetry_ac_validation;
SELECT COUNT(*) AS legacy_rows FROM telemetry_ac_real_legacy;

-- Exemple de promotion APRES validation terrain (ne pas exécuter tel quel) :
-- INSERT INTO telemetry_trust_registry(
--     device_id, boot_id, status, firmware, validation_note, validated_at, updated_at
-- ) VALUES (
--     'borne-01', <BOOT_ID>, 'TRUSTED', '0.2.12-field',
--     'Wi-Fi outage + replay + reboot session tests passed', NOW(), NOW()
-- )
-- ON CONFLICT (device_id, boot_id) DO UPDATE SET
--     status = EXCLUDED.status,
--     firmware = EXCLUDED.firmware,
--     validation_note = EXCLUDED.validation_note,
--     validated_at = EXCLUDED.validated_at,
--     updated_at = NOW();
