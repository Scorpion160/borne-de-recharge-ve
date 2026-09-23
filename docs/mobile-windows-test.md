# Version Windows VE-SCOPE pour essais

Installer Visual Studio avec le module **Developpement Desktop en C++** et
verifier dans PowerShell :

```powershell
flutter doctor -v
```

Depuis la racine du depot :

```powershell
.\scripts\build-vescope-windows.ps1
```

Le script cree `frontend/vescope_flutter/windows` si ce dossier manque,
genere l'icone Windows VE-SCOPE, execute `flutter analyze` et les tests,
puis compile l'application avec les adresses HTTPS et WebSocket de production.

L'executable est `vescope_supervisor.exe` sous
`frontend/vescope_flutter/build/windows/x64/runner/Release` (selon la version
Flutter, `build/windows/runner/Release`). Pour le lancer sur un autre PC,
utiliser `frontend/vescope_flutter/build/VE-SCOPE-Windows.zip` : extraire
**tous** les fichiers dans un meme dossier, puis ouvrir l'executable. Les DLL
et le dossier `data` sont indispensables. L'autre PC peut egalement necessiter
les composants redistribuables Microsoft Visual C++.

Le workflow GitHub Actions « VE-SCOPE Windows » produit egalement ce ZIP et le
propose en artefact sur la page de son execution.

Dans l'onglet Sessions, le bouton « Telecharger les mesures de cette session »
exporte les points de la recharge choisie, meme lorsque celle-ci est plus
ancienne que la plage de 24 heures. Ce bouton utilise le nouvel endpoint du
Hub : il faut aussi deployer la version correspondante du backend sur le VPS.

Les identifiants HTTPS du site sont demandes a la premiere connexion.
Apres une connexion valide, ils sont memorises de facon securisee sur le PC ;
les ouvertures suivantes preremplissent les champs sans connexion automatique.
Le bouton « Effacer les identifiants » permet de supprimer les identifiants
enregistres. Les exports CSV s'ouvrent dans le navigateur et peuvent demander
une nouvelle authentification.

La compilation est executee sur Windows, sur votre PC equipe de Visual Studio
ou sur le runner GitHub Actions ; cet environnement de preparation ne dispose
pas de la toolchain.
