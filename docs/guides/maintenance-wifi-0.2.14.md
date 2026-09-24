# Firmware 0.2.14-field : Wi-Fi prioritaire et accès local

## Préparation et premier flash physique

Sur la machine Windows, dans `firmware/vescope-core-esp32`, conserver votre
`include/secrets.h` privé. Il doit contenir les mots de passe AP et OTA
personnels. Le SSID prioritaire est `SN` par défaut ; son mot de passe se
configure exclusivement dans ce fichier privé (`VESCOPE_PRIORITY_WIFI_PASSWORD`)
ou via la page `/wifi` après le flash. Ne jamais ajouter `secrets.h` à GitHub.

Compiler `pio run -e esp32dev`. Vérifier la taille sous 1 572 864 octets
et le succès de la compilation. Pour la récupération USB, brancher la carte
hors tension dangereuse, sélectionner son port et exécuter `pio run -e esp32dev
-t upload --upload-port COMx`. Le flash USB normal conserve la NVS ; éviter
`erase_flash`, qui effacerait Wi-Fi, secrets locaux et données persistantes.

## Après le redémarrage

1. Confirmer sur le moniteur série `Boot firmware 0.2.14-field` et vérifier
   qu'aucun redémarrage en boucle ne se produit.
2. Se connecter au point d'accès protégé `VE-SCOPE-borne-01`, ouvrir
   `http://192.168.4.1/api/connectivity`, puis `http://192.168.4.1/wifi`.
   La page `/wifi` demande l'utilisateur et le mot de passe Web OTA.
3. Entrer le SSID `SN` et son mot de passe dans « Réseau prioritaire ».
   Conserver le Wi-Fi de l'école en « Réseau de secours », avec son portail
   captif si nécessaire. Enregistrer ; l'ESP32 redémarre et garde ces profils
   en NVS après les prochaines mises à jour OTA.
4. Activer le partage de connexion SN en 2,4 GHz. Après connexion, vérifier
   `wifi_ssid: SN`, `wifi_connected: true` et `captive_portal_enabled: false`.
   Vérifier la reprise des statuts et diagnostics dans le Hub, ainsi que la
   décroissance de `durable_pending_telemetry` si des mesures étaient en file.
5. Couper SN et vérifier le basculement vers l'école ; rallumer SN, attendre
   environ 60 secondes et vérifier le retour sur SN. Après chaque basculement,
   le téléphone connecté à l'AP local peut devoir se réassocier : les deux
   interfaces partagent la même radio Wi-Fi et son canal.
6. Tester `/update` sur l'AP puis une OTA avec un binaire connu correct ;
   confirmer le redémarrage, la version dans `/api/status`, l'AP et le retour
   du statut au Hub. La visite de `/update` suspend le cloud deux minutes pour
   préparer le transfert ; un transfert effectif suspend le cloud jusqu'à sa
   fin. La télémétrie durable continue localement pendant cette période.

Une borne privée d'alimentation, dont le programme ne démarre plus ou dont la
radio tombe matériellement en panne reste inaccessible par Wi-Fi. Prévoir le
port USB de secours et noter les messages série lors de ce premier flash :
ils aideront à distinguer une panne d'alimentation, un boot défectueux et une
panne purement réseau.

## Sauvegardes du serveur

La ligne `0 2 * * * ...` tapée seule dans Bash n'installe aucune tâche.
Sur le VPS, vérifier `crontab -l` et installer **une seule fois** via
`crontab -e` la ligne suivante :

```cron
0 2 * * * /bin/bash /opt/vescope/scripts/backup-vescope-postgres.sh >> /var/log/vescope-backup.log 2>&1
```

Puis vérifier `crontab -l` et contrôler le journal et le dump après la nuit.
La copie du dump sur le PC a confirmé une sauvegarde manuelle, pas la tâche
quotidienne.
