# Firmware 0.2.13-field : acces local de maintenance

## Modification
Le point d'acces protege VE-SCOPE-borne-01 demarre au boot en AP+STA et reste
actif apres le retour du reseau primaire. L'arret explicite depuis /update
reste valable jusqu'au prochain redemarrage. Un echec de demarrage AP est
retente toutes les 30 secondes.

Tant qu'un appareil est associe a cet AP, aucun nouvel appel synchrone
portail captif, publication cloud, connexion MQTT ou mqtt.loop n'est lance.
L'acquisition et le journal durable existants continuent. Deconnecter tous
les appareils de l'AP pour reprendre les envois. Ne pas laisser un telephone
en reconnexion automatique sur cet AP apres intervention.

## Limites
Ce correctif priorise l'acces AP direct ; il ne rend pas asynchrones les
appels reseau lorsque personne n'est connecte a l'AP. Une operation deja
engagee peut encore retarder la premiere reponse. AP et STA partagent la
radio ; les reconnexions automatiques STA et la coexistence BLE restent
a evaluer sur la carte. L'acces via le Wi-Fi de l'ecole peut toujours etre
affecte par sa couverture ou ses regles reseau.

## Validation requise avant de declarer le probleme resolu
Compilation non executee dans l'environnement de preparation (PlatformIO
absent). Depuis firmware/vescope-core-esp32 :
```powershell
pio run -e esp32dev
```
Verifier success et la taille compatible OTA. Conserver secrets.h local.
Ne televerser que .pio/build/esp32dev/firmware.bin via /update, pas les
images bootloader/partitions. Cette mise a jour n'efface pas volontairement
les configurations NVS et utilise le partitionnement existant.

1. Au boot, verifier AP visible, mot de passe requis, IP 192.168.4.1.
2. Attendre plus de 30 s apres retour du reseau primaire : AP toujours visible.
3. Connecter un PC ; charger plusieurs fois /api/status et /api/connectivity,
   puis /update (authentification requise), avec cloud indisponible.
4. Confirmer local_maintenance_active=true et ap_clients>0 ; verifier que les
   sequences d'acquisition et la file durable progressent pendant maintenance.
5. Deconnecter le PC : confirmer reprise cloud et vidage de la file durable.
6. Verifier OTA reussie, redemarrage en 0.2.13-field, puis acces AP conserve.
7. Tester l'arret explicite AP puis le retour AP au prochain boot.

## Recuperer l'ancien firmware
Le nouveau code ne peut pas activer l'AP sur une borne qui ne l'a pas encore
recu. Il faut retrouver /update sur le reseau primaire ou sur son AP de secours.
Si aucun acces radio ne revient, une intervention locale sur l'ESP32 est
necessaire ; ne pas lancer de televersement vers une IP non confirmee.
