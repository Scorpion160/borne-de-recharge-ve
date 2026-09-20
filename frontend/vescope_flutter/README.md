# VE-SCOPE Flutter

Client multiplateforme de supervision de la borne VE-SCOPE.

## Objectif

Remplacer progressivement le frontend React de référence par un client Flutter unique pour Web, Android et iOS, sans modifier l'API VE-SCOPE Hub.

Le frontend React reste la référence fonctionnelle jusqu'à parité complète.

## Architecture cible

- `lib/core/` : configuration, thème, transport HTTP/WebSocket.
- `lib/models/` : modèles VE-SCOPE.
- `lib/state/` : état applicatif et synchronisation Hub.
- `lib/ui/` : shell responsive et pages.

## API réutilisée

- `GET /health`
- `GET /api/v1/devices/borne-01/sessions`
- `GET /api/v1/devices/borne-01/events`
- `GET /api/v1/devices/borne-01/telemetry/series`
- `GET/PUT /api/v1/devices/borne-01/settings`
- `GET /api/v1/devices/borne-01/exports/*.csv`
- `WS /api/v1/ws/devices/borne-01`

## Bootstrap local Windows

Après avoir récupéré la branche `agent/vescope-flutter-v1` :

```powershell
cd C:\Users\DIOP\Documents\borne-de-recharge-ve\frontend\vescope_flutter
flutter create --platforms=web,android --project-name vescope_supervisor --org com.vescope .
git restore README.md pubspec.yaml analysis_options.yaml lib
flutter pub get
flutter analyze
```

Le dossier `lib/` et le `pubspec.yaml` de cette branche constituent la source applicative. Les fichiers de plateforme (`web/`, `android/`) sont générés localement par Flutter.

## Connexion locale au Hub réel

En développement Web, `Uri.base.origin` correspond à `localhost:<port Flutter>`. Sans configuration explicite, l'application cherche donc le Hub sur le serveur Flutter local et reste hors ligne.

Pour tester les vraies données sans exposer le port interne du Hub ni embarquer de secret, ouvrir un tunnel SSH local vers le VPS dans une deuxième fenêtre PowerShell :

```powershell
ssh -N -L 8010:127.0.0.1:8010 <utilisateur-vps>@<hote-vps>
```

Puis lancer Flutter dans la première fenêtre en ciblant ce tunnel :

```powershell
flutter run -d edge `
  --dart-define=VESCOPE_API_BASE=http://127.0.0.1:8010 `
  --dart-define=VESCOPE_WS_URL=ws://127.0.0.1:8010/api/v1/ws/devices/borne-01
```

Le Hub autorise les requêtes CORS nécessaires au développement local. Le tunnel SSH évite aussi l'authentification HTTP publique du domaine de production pendant le développement.

Pour la version Web déployée sur `vescope.kerunjombor.net`, aucun `dart-define` d'URL n'est nécessaire : le client utilise le même origin que le Hub, exactement comme le frontend React actuel.

Aucun secret ne doit être ajouté au dépôt ni passé via `--dart-define`.

## Étapes de migration

1. Shell responsive + thème VE-SCOPE.
2. Connexion HTTP/WebSocket réelle.
3. Vue générale.
4. Mesures AC et Historique.
5. Données, Sessions, Alarmes, Diagnostic, Paramètres.
6. Parité Web puis Android/iOS.
7. Basculer le domaine Web vers Flutter uniquement après validation complète.
