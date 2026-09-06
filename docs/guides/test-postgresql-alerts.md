# Tester PostgreSQL et le moteur d'alarmes VE-SCOPE

Cette étape valide la persistance des données MQTT et la génération d'alarmes par VE-SCOPE Hub.

## 1. Mettre la branche à jour

```powershell
cd $HOME\Documents\borne-de-recharge-ve
git switch agent/bootstrap-vescope-supervisor
git pull
```

## 2. Reconstruire la stack

Laisser le simulateur arrêté pendant la reconstruction.

```powershell
docker compose -f infrastructure/docker-compose.dev.yml down
docker compose -f infrastructure/docker-compose.dev.yml up -d --build
```

Vérifier les trois services :

```powershell
docker compose -f infrastructure/docker-compose.dev.yml ps
```

Les conteneurs attendus sont :

- `vescope_mqtt` ;
- `vescope_postgres` ;
- `vescope_hub`.

## 3. Vérifier la santé du Hub

```powershell
Invoke-RestMethod http://localhost:8003/health
```

Les champs attendus sont :

```text
ok                 : True
mqtt_connected     : True
database_connected : True
```

## 4. Redémarrer le simulateur

Dans un autre PowerShell :

```powershell
cd $HOME\Documents\borne-de-recharge-ve\simulator\vescope-core
.\.venv\Scripts\Activate.ps1
python simulator.py --broker localhost --port 1883 --device-id borne-01
```

## 5. Vérifier l'historisation de la télémétrie

Après 10 à 20 secondes :

```powershell
(Invoke-RestMethod 'http://localhost:8003/api/v1/devices/borne-01/telemetry?limit=10').items
```

Les lignes doivent contenir notamment `measured_at`, `sequence`, `voltage_v`, `current_a`, `active_power_w`, `power_factor` et `energy_total_wh`.

## 6. Vérifier la session persistée

```powershell
(Invoke-RestMethod 'http://localhost:8003/api/v1/devices/borne-01/sessions?limit=10').items
```

La session active doit apparaître avec le même `session_id` que dans Supervisor.

## 7. Vérifier les événements

```powershell
(Invoke-RestMethod 'http://localhost:8003/api/v1/devices/borne-01/events?limit=50').items
```

En fonctionnement normal, cette liste peut être vide.

## 8. Tester l'alarme de perte de télémétrie

Laisser Supervisor, Mosquitto, PostgreSQL et le Hub actifs, puis arrêter uniquement le simulateur avec `Ctrl+C`.

Après environ 5 secondes :

```powershell
(Invoke-RestMethod 'http://localhost:8003/api/v1/devices/borne-01/events?limit=10').items
```

Une alarme `AC_TELEMETRY_STALE` de niveau `ALERT` doit apparaître. Elle ne doit être enregistrée qu'une seule fois tant que la panne persiste.

Redémarrer ensuite le simulateur. Un événement `AC_TELEMETRY_STALE_RECOVERED` de niveau `INFO` doit être créé lorsque les données recommencent à arriver.

## 9. Seuils actuels de développement

Les seuils sont configurables dans `infrastructure/docker-compose.dev.yml` :

| Règle | Valeur de développement |
|---|---:|
| Sous-tension | 207 V |
| Surtension | 253 V |
| Facteur de puissance faible | 0,90 |
| Fréquence basse | 49 Hz |
| Fréquence haute | 51 Hz |
| Télémétrie périmée | 5 s |

Ces seuils sont des paramètres de développement et devront être validés définitivement selon la borne, les protections électriques et les exigences du projet avant déploiement terrain.

## 10. Persistance Docker

Les données PostgreSQL sont conservées dans le volume Docker `vescope_postgres_data`. Un simple `docker compose down` ne supprime donc pas l'historique.

Pour supprimer volontairement toute la base de développement :

```powershell
docker compose -f infrastructure/docker-compose.dev.yml down -v
```

Ne pas utiliser `-v` si l'on souhaite conserver les sessions et mesures déjà enregistrées.
