# VE-SCOPE Hub

VE-SCOPE Hub est la passerelle entre les données terrain VE-SCOPE Core, PostgreSQL et les interfaces de supervision.

```text
VE-SCOPE Core -> HTTPS/MQTT -> VE-SCOPE Hub -> PostgreSQL -> REST/WebSocket -> Supervisor / jumeau numérique
```

Le navigateur n'accède pas directement au broker MQTT. Le Hub centralise la validation du contrat, la persistance, le dernier état connu, les alarmes et la diffusion temps réel.

## Données scientifiques et jumeau numérique

Les données AC sont classées côté PostgreSQL en quatre états :

- `LEGACY` : données physiques historiques non admissibles comme ground truth dynamique ;
- `VALIDATION` : nouvelles données terrain en cours de qualification ;
- `TRUSTED` : boot explicitement validé après essais terrain ;
- `REJECTED` : boot explicitement exclu.

Aucun `boot_id` n'est promu automatiquement en `TRUSTED`.

L'export opérationnel historique reste disponible :

```text
GET /api/v1/devices/{device_id}/exports/telemetry.csv?range=24h
```

Il peut contenir plusieurs classes de confiance et ne doit pas être utilisé comme dataset de référence du jumeau numérique.

L'export scientifique dédié est :

```text
GET /api/v1/devices/{device_id}/exports/telemetry-trusted.csv?range=24h
```

Il lit exclusivement `telemetry_ac_trusted`, sans agrégation ni rééchantillonnage, et conserve notamment `sample_id`, `boot_id`, `sequence`, `session_id`, `quality`, les mesures électriques, le délai d'ingestion et les métadonnées de validation du boot.

Plages disponibles : `1h`, `24h`, `7d`, `30d`.

## Fonctions principales

- ingestion HTTPS durable et MQTT ;
- persistance PostgreSQL ;
- WebSocket temps réel par borne ;
- historique de télémétrie, sessions et événements ;
- moteur d'alarmes et seuils persistants ;
- exports CSV opérationnels ;
- export CSV scientifique `TRUSTED` pour la caractérisation et le jumeau numérique.
