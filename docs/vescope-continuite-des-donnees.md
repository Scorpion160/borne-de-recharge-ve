# Prévenir une session de recharge sans mesures

Le résumé d'une session et ses relevés AC sont transmis séparément. Une session
visible dans l'application ne prouve pas que ses relevés ont été conservés.

## Avant une recharge

1. Installer et confirmer sur la borne `0.2.13-field` ou une version ultérieure.
   La version `0.2.11-field`, utilisée le 18 septembre, ne fournissait pas la
   même garantie de conservation des relevés pendant les interruptions.
2. Laisser la borne connectée à Internet et vérifier dans `/api/status` que
   `durable_store_ok` vaut `true`. Dans les diagnostics reçus par le Hub,
   vérifier que `durable_queue_error` vaut `false` et que le nombre de
   `durable_pending_telemetry` redescend jusqu'à zéro après reconnexion.
3. Depuis le VPS, copier les deux scripts de ce dépôt dans
   `/opt/vescope/scripts`, puis exécuter :

   ```bash
   docker exec -i vescope_hub python - < /opt/vescope/scripts/verify-vescope-integrity.py
   ```

   Une réponse `OK` atteste d'une mesure récente effectivement enregistrée dans
   PostgreSQL et de la disponibilité de la file de l'ESP32. Un échec doit être
   examiné avant d'utiliser la recharge comme essai documenté.

## Pendant et après la recharge

Exécuter le même contrôle après deux minutes de recharge, puis après la fin.
Il affiche le nombre de relevés associés à chacune des sessions des dernières
24 heures. Le contrôle peut détecter une session sans mesures ; il ne fabrique
jamais de relevés. Attendre que la file des mesures en attente revienne à zéro.
Le firmware conserve les relevés en attente dans SPIFFS et ne les retire
qu'après une confirmation HTTPS de l'enregistrement par le Hub. Si HTTPS 443
ne fonctionne pas et que la file reste pleine, les nouvelles mesures peuvent
être perdues : `durable_queue_error` doit donc être surveillé.

## Sauvegarde de la base

Installer `scripts/backup-vescope-postgres.sh` dans `/opt/vescope/scripts` et
faire une première sauvegarde sur le VPS :

```bash
bash /opt/vescope/scripts/backup-vescope-postgres.sh
```

Le script sauvegarde au format PostgreSQL personnalisé dans
`/opt/vescope/backups/postgres`, vérifie que le fichier est lisible, et laisse
intacte la base active. Les fichiers restent conservés jusqu'à leur archivage
manuel. Pour automatiser une sauvegarde quotidienne à 02:00 UTC, installer
une tâche cron sous le compte qui peut utiliser Docker :

```cron
0 2 * * * /bin/bash /opt/vescope/scripts/backup-vescope-postgres.sh >> /var/log/vescope-backup.log 2>&1
```

Copier périodiquement les sauvegardes hors du VPS et tester une restauration
dans une base temporaire. Une sauvegarde ne peut conserver que les mesures qui
ont déjà atteint PostgreSQL ; elle complète donc le contrôle de bout en bout.

La première recharge du 18 septembre est antérieure à ces contrôles. Ses trois
fragments de résumé totalisent 773 Wh, mais aucune mesure AC de cette journée
n'est présente dans la base actuelle.
