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

## Bootstrap local

Après avoir récupéré la branche `agent/vescope-flutter-v1` :

```powershell
cd C:\Users\DIOP\Documents\borne-de-recharge-ve\frontend\vescope_flutter
flutter create --platforms=web,android,ios --project-name vescope_supervisor .
flutter pub get
flutter run -d chrome
```

Le dossier `lib/` et le `pubspec.yaml` de cette branche constituent la source applicative. Si `flutter create` propose de remplacer un fichier déjà présent, conserver la version du dépôt pour `lib/`, `pubspec.yaml` et `analysis_options.yaml`.

Pour Android/iOS, l'URL du Hub est par défaut `https://vescope.kerunjombor.net`. Pour un environnement différent :

```powershell
flutter run -d chrome --dart-define=VESCOPE_API_BASE=https://vescope.kerunjombor.net
```

Aucun secret ne doit être ajouté au dépôt ni passé via `--dart-define`.

## Étapes de migration

1. Shell responsive + thème VE-SCOPE.
2. Connexion HTTP/WebSocket réelle.
3. Vue générale.
4. Mesures AC et Historique.
5. Données, Sessions, Alarmes, Diagnostic, Paramètres.
6. Parité Web puis Android/iOS.
7. Basculer le domaine Web vers Flutter uniquement après validation complète.
