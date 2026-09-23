# APK VE-SCOPE pour essais

Depuis la racine du depot, sous PowerShell :

```powershell
.\scripts\build-vescope-apk.ps1
```

Le script ajoute la permission INTERNET au manifeste Android local, nomme
l'application VE-SCOPE, desactive la sauvegarde Android des donnees locales,
genere les icones du lanceur avec le logo VE-SCOPE, execute pub get, analyze,
les tests de connexion et de memorisation des identifiants,
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
identifiants OTA de l'ESP32. Apres une connexion valide, ils sont enregistres
dans le stockage securise du telephone. Au prochain demarrage ou apres une
deconnexion, le formulaire est prerempli ; le mot de passe reste masque et
l'utilisateur appuie lui-meme sur « Se connecter ». Le bouton « Effacer les
identifiants » supprime cet enregistrement. Aucun identifiant n'est ajoute
au depot, aux dart-defines ni aux URL.
Les exports CSV ouvrent le navigateur ; il peut demander les identifiants
une seconde fois. Le parcours web existant conserve l'authentification du
navigateur. Une connexion au serveur ne garantit pas une telemetrie recente.

## Verification sur telephone
- Mauvais mot de passe : refus visible, possibilite de corriger.
- Identifiants valides : tableau de bord et WebSocket connecte.
- Parametres : lecture et enregistrement accessibles.
- Mode avion puis retour reseau : reconnexion WebSocket.
- Deconnexion : retour au formulaire, anciennes mesures retirees.
- Redemarrage : identifiants preremplis, sans connexion automatique.
- Effacer les identifiants : formulaire vide au demarrage suivant.
- Icône du lanceur : logo VE-SCOPE au lieu de l'icône Flutter.
- Export : fichier CSV obtenu dans le navigateur.

## Etat de validation
Code relu ; Flutter et le SDK Android sont absents de l'environnement de
preparation. Analyze, tests et compilation doivent donc etre executes sur
le PC Windows via le script avant de considerer l'APK valide.
La signature de distribution reste a integrer. Aucun changement iOS n'est inclus
dans ce lot.
