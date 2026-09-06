# VE-SCOPE Supervisor

Première interface Web de supervision du projet VE-SCOPE.

## État actuel

La V0 fonctionne en **mode simulation intégré** : aucune borne, aucun broker MQTT et aucun backend ne sont nécessaires pour afficher le tableau de bord.

Écrans présents :

- Vue générale ;
- Mesures AC ;
- Sessions ;
- Alarmes ;
- Diagnostic.

Les données simulées suivent le modèle défini dans `docs/protocols/mqtt-v1.md` afin de faciliter le remplacement ultérieur du mock par les données réelles de VE-SCOPE Hub.

## Lancement

Prérequis : Node.js LTS.

```bash
cd frontend/vescope-supervisor
npm install
npm run dev
```

Puis ouvrir l'URL indiquée par Vite, généralement :

```text
http://localhost:5173
```

## Build

```bash
npm run build
npm run preview
```

## Prochaines étapes

1. extraire les services de données du composant principal ;
2. ajouter le client API/WebSocket vers VE-SCOPE Hub ;
3. implémenter l'historique réel des sessions ;
4. ajouter la gestion des alarmes et leur acquittement ;
5. intégrer les données JK BMS en V1.1 ;
6. ajouter les vues chargeur rapide et énergie hybride en V2.
