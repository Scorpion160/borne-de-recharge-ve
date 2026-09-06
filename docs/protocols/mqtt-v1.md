# Contrat MQTT VE-SCOPE — version 1

## Objectif

Ce document définit le contrat d'échange initial entre VE-SCOPE Core, le simulateur, VE-SCOPE Hub et les outils de supervision.

## Préfixe

```text
vescope/{device_id}/...
```

Exemple :

```text
vescope/borne-01/telemetry/ac
```

## Topics

| Topic | QoS | Retain | Rôle |
|---|---:|---:|---|
| `vescope/{id}/status` | 1 | oui | disponibilité et état global |
| `vescope/{id}/telemetry/ac` | 0 | non | mesures AC temps réel |
| `vescope/{id}/session/live` | 0 | non | session active |
| `vescope/{id}/session/summary` | 1 | non | résumé de fin de session |
| `vescope/{id}/alerts` | 1 | non | alarmes et événements importants |
| `vescope/{id}/diagnostics` | 0 | non | diagnostic VE-SCOPE Core |
| `vescope/{id}/bms` | 0 | non | données JK BMS, V1.1 |
| `vescope/{id}/charger` | 0 | non | données chargeur rapide, V2 |

## Disponibilité

Le client MQTT doit utiliser un Last Will and Testament sur :

```text
vescope/{id}/status
```

Payload de déconnexion inattendue :

```json
{
  "schema": 1,
  "device_id": "borne-01",
  "online": false,
  "state": "OFFLINE"
}
```

Après connexion :

```json
{
  "schema": 1,
  "device_id": "borne-01",
  "online": true,
  "state": "IDLE",
  "firmware": "0.1.0"
}
```

## Télémétrie AC

Topic :

```text
vescope/{id}/telemetry/ac
```

Payload :

```json
{
  "schema": 1,
  "device_id": "borne-01",
  "timestamp": "2026-08-07T09:45:30Z",
  "sequence": 1542,
  "quality": "GOOD",
  "voltage_v": 230.2,
  "current_a": 9.72,
  "active_power_w": 2170.0,
  "apparent_power_va": 2237.5,
  "non_active_power_var_est": 545.0,
  "power_factor": 0.970,
  "frequency_hz": 50.01,
  "energy_total_wh": 15432.0
}
```

`non_active_power_var_est` reste explicitement une estimation tant que le système repose sur le PZEM-004T.

## Session active

Topic :

```text
vescope/{id}/session/live
```

```json
{
  "schema": 1,
  "device_id": "borne-01",
  "session_id": "VE01-20260807-091500",
  "state": "CHARGING",
  "started_at": "2026-08-07T09:15:00Z",
  "duration_s": 1830,
  "energy_wh": 1102.5,
  "average_power_w": 2168.4,
  "max_power_w": 2218.0,
  "max_current_a": 9.95,
  "average_power_factor": 0.968
}
```

## Résumé de session

Topic :

```text
vescope/{id}/session/summary
```

Le résumé doit inclure au minimum :

- identifiant de session ;
- début et fin ;
- durée ;
- énergie AC ;
- puissance moyenne et maximale ;
- courant maximal ;
- tension min/max/moyenne ;
- PF min/moyen ;
- fréquence min/max ;
- nombre d'interruptions ;
- cause de fin.

## Alarmes

Topic :

```text
vescope/{id}/alerts
```

```json
{
  "schema": 1,
  "device_id": "borne-01",
  "timestamp": "2026-08-07T09:44:02Z",
  "severity": "WARNING",
  "code": "AC_LOW_POWER_FACTOR",
  "message": "Facteur de puissance inférieur au seuil configuré",
  "value": 0.82,
  "threshold": 0.90,
  "source": "pzem_ac"
}
```

Niveaux : `INFO`, `WARNING`, `ALERT`, `CRITICAL`.

## Qualité des données

Valeurs autorisées :

- `GOOD` : mesure récente et valide ;
- `STALE` : dernière valeur connue mais trop ancienne ;
- `INVALID` : donnée reçue mais invalide ;
- `UNAVAILABLE` : source indisponible ;
- `ESTIMATED` : valeur calculée ou estimée.

## Versionnement

Le champ `schema` est obligatoire. Toute évolution cassante du payload incrémente ce numéro.
