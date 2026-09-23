# APK VE-SCOPE pour essais

Depuis la racine du depot, sous PowerShell :

```powershell
.\scripts\build-vescope-apk.ps1
```

Le script ajoute la permission INTERNET au manifeste Android local, nomme
l'application VE-SCOPE, execute pub get, analyze, les tests de connexion,
puis construit build/app/outputs/flutter-apk/app-release.apk dans
frontend/vescope_flutter. Le projet Android existant sur le PC est conserve.
Le dossier Android n'est pas encore suivi dans ce depot ; s'il manque :

```powershell
cd frontend/vescope_flutter
flutter create --platforms=android --org com.vescope --project-name vescope_supervisor .
```

La configuration Android transmise utilise la cle de debug pour le build
release : cet APK est destine aux essais, pas a la publication Play Store.
Garder cette cle locale pour les mises a jour de test suivantes.

## Connexion
Utiliser les identifiants HTTP du site vescope.kerunjombor.net, pas les
identifiants OTA de l'ESP32. Ils restent en memoire jusqu'a la deconnexion
ou la fermeture du processus. Aucun identifiant n'est ajoute au depot,
aux dart-defines, aux URL ou au stockage permanent.
Les exports CSV ouvrent le navigateur ; il peut demander les identifiants
une seconde fois. Le parcours web existant conserve l'authentification du
navigateur. Une connexion au serveur ne garantit pas une telemetrie recente.

## Verification sur telephone
- Mauvais mot de passe : refus visible, possibilite de corriger.
- Identifiants valides : tableau de bord et WebSocket connecte.
- Parametres : lecture et enregistrement accessibles.
- Mode avion puis retour reseau : reconnexion WebSocket.
- Deconnexion : retour au formulaire, anciennes mesures retirees.
- Export : fichier CSV obtenu dans le navigateur.

## Etat de validation
Code relu ; Flutter et le SDK Android sont absents de l'environnement de
preparation. Analyze, tests et compilation doivent donc etre executes sur
le PC Windows via le script avant de considerer l'APK valide.
Le logo lanceur personnalise et la signature de distribution restent a
integrer. Aucun changement iOS n'est inclus dans ce lot.
