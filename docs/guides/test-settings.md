# Validation des paramètres d'alarme VE-SCOPE

## 1. Mettre à jour le dépôt

```powershell
cd $HOME\Documents\borne-de-recharge-ve
git switch agent/bootstrap-vescope-supervisor
git pull
```

## 2. Reconstruire VE-SCOPE Hub

```powershell
docker compose -f infrastructure/docker-compose.dev.yml up -d --build hub
```

Vérifier :

```powershell
Invoke-RestMethod http://localhost:8003/health
```

La version attendue est `0.4.0`.

## 3. Lire la configuration actuelle

```powershell
Invoke-RestMethod http://localhost:8003/api/v1/devices/borne-01/settings
```

Valeurs initiales : 207 V / 253 V, PF 0,90, fréquence 49–51 Hz et perte télémétrie 5 s.

## 4. Modifier depuis Supervisor

Ouvrir `Paramètres`, modifier une valeur puis cliquer sur `Enregistrer`. Un événement `ALARM_SETTINGS_UPDATED` est généré dans le journal.

## 5. Vérifier la persistance

Relire l'API puis redémarrer le Hub :

```powershell
docker compose -f infrastructure/docker-compose.dev.yml restart hub
Invoke-RestMethod http://localhost:8003/api/v1/devices/borne-01/settings
```

La valeur modifiée doit rester inchangée, ce qui valide sa persistance dans PostgreSQL.

## 6. Test fonctionnel rapide

Dans Supervisor, définir temporairement `Perte de télémétrie = 10 s`, enregistrer, puis arrêter le simulateur. L'alarme `AC_TELEMETRY_STALE` ne doit apparaître qu'après environ 10 secondes. Remettre ensuite la valeur à 5 s.

> Les seuils VE-SCOPE sont des seuils de supervision logicielle. Ils ne remplacent jamais les protections matérielles de la borne, du chargeur ou du BMS.
