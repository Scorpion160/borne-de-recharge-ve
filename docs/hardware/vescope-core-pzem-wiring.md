# VE-SCOPE Core — câblage ESP32 / PZEM-004T

## Hypothèse matérielle

Cette première intégration vise le **PZEM-004T v3** avec pince de courant et interface série Modbus RTU.

Le prototype actuel utilise un **ESP32 classique DevKit / WROOM-32**. L'ESP32-S3 reste une cible logicielle secondaire, mais il n'est pas requis pour commencer.

Avant raccordement définitif, relever sur le matériel réellement disponible :

- référence/version exacte du PZEM ;
- tension logique de sa broche TX ;
- brochage sérigraphié ;
- calibre de la pince de courant ;
- référence exacte de la carte ESP32 si ce n'est pas un DevKit/WROOM-32 standard.

## Partie basse tension — prototype ESP32 classique

Configuration firmware par défaut :

| PZEM | VE-SCOPE Core ESP32 classique |
|---|---|
| TX | adaptation de niveau -> GPIO16 (RX2) |
| RX | GPIO17 (TX2) -> PZEM RX, adaptation si nécessaire |
| GND | GND logique commun |
| 5 V | alimentation 5 V conforme au module |

### Choix de l'UART

GPIO16/GPIO17 sont utilisés comme UART2 sur le prototype ESP32 classique afin de laisser l'UART0 de la carte disponible pour :

- programmation ;
- logs ;
- console série USB vers le PC.

La matrice GPIO de l'ESP32 permet le routage matériel de l'UART sur ces broches. Le firmware les configure explicitement.

### Important — niveaux logiques

Les GPIO de l'ESP32 fonctionnent en **3,3 V** et ne doivent pas recevoir directement un signal 5 V non compatible.

Pour le prototype :

1. ne pas connecter immédiatement `PZEM TX` à l'ESP32 ;
2. alimenter correctement le module selon sa documentation ;
3. mesurer le niveau logique de `TX` au multimètre/oscilloscope si possible ;
4. si le signal atteint environ 5 V, insérer une adaptation 5 V -> 3,3 V ;
5. pour le PCB final, prévoir une adaptation de niveau dédiée.

Une solution de prototype simple pour la ligne **PZEM TX -> ESP32 RX** est un pont diviseur résistif correctement calculé ; pour le PCB final, une interface logique dédiée sera préférable.

## Partie secteur et pince de courant

Le PZEM mesure une tension secteur potentiellement dangereuse. Les raccordements L/N et la pince de courant doivent être réalisés **hors tension**, avec protections adaptées et par une personne compétente pour le travail sur le secteur.

La pince de courant se place autour **d'un seul conducteur actif**, typiquement la phase. Ne jamais entourer simultanément phase et neutre avec la pince.

Architecture fonctionnelle du prototype :

```text
Réseau AC 230 V
   |
   +---- L/N ----------------------> PZEM-004T mesure tension
   |
   +---- phase ----[ pince CT ]----> chargeur AC/DC du VE

PZEM UART
   |
   +---- TX -> adaptation 5V/3V3 -> ESP32 GPIO16 / RX2
   +---- RX <- adaptation éventuelle <- ESP32 GPIO17 / TX2
   +---- GND ------------------------ ESP32 GND logique

ESP32 DevKit
   |
   +---- USB-UART -----------------> PC / logs / flash
   +---- Wi-Fi --------------------> MQTT / VE-SCOPE Hub
```

## Variante ESP32-S3 conservée dans le firmware

Si un ESP32-S3 est utilisé plus tard :

| Signal | ESP32-S3 |
|---|---:|
| PZEM TX -> RX | GPIO18 |
| TX -> PZEM RX | GPIO17 |

Cette variante est compilée par l'environnement PlatformIO `esp32-s3-devkitc-1` mais n'est pas nécessaire pour la phase prototype actuelle.

## Placement dans la borne

Pour le futur PCB VE-SCOPE Core :

- séparer physiquement la zone secteur de la zone SELV/basse tension ;
- ne pas faire passer les pistes UART/Wi-Fi près des conducteurs de puissance ;
- conserver l'antenne ESP32 éloignée des masses métalliques et convertisseurs à découpage ;
- filtrer l'alimentation 5 V / 3,3 V ;
- prévoir protections ESD/EMI sur les connecteurs accessibles ;
- utiliser des borniers et connecteurs détrompés ;
- documenter le sens de la pince de courant et les connexions L/N ;
- prévoir des points de test `5V`, `3V3`, `GND`, `PZEM_TX`, `PZEM_RX`.

## Séquence de mise au point recommandée

1. ESP32 classique seul par USB ;
2. compilation/téléversement du firmware `esp32dev` ;
3. validation Wi-Fi + MQTT sans PZEM ;
4. contrôle du brochage et des niveaux logiques du PZEM ;
5. connexion UART basse tension ;
6. lecture Modbus avec PZEM correctement alimenté ;
7. lecture tension secteur sans charge ;
8. ajout d'une charge faible connue ;
9. comparaison avec multimètre et pince ampèremétrique de référence ;
10. validation MQTT vers Mosquitto ;
11. comparaison Supervisor / instrument de référence ;
12. seulement ensuite intégration mécanique dans la borne.

## Précaution prototype

Tant que la carte ESP32 exacte et le PZEM physique n'ont pas été photographiés/identifiés, considérer GPIO16/GPIO17 comme **brochage de référence pour un DevKit ESP32-WROOM-32 standard**, et vérifier la sérigraphie de votre carte avant branchement.
