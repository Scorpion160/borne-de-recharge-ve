# VE-SCOPE Core — câblage ESP32-S3 / PZEM-004T

## Hypothèse matérielle

Cette première intégration vise le PZEM-004T v3 avec pince de courant et interface série Modbus RTU.

Avant raccordement définitif, relever sur le module réellement disponible :

- référence/version exacte ;
- tension logique de la broche TX ;
- brochage sérigraphié ;
- calibre de la pince de courant.

## Partie basse tension

Configuration firmware initiale :

| PZEM | VE-SCOPE Core |
|---|---|
| TX | adaptation de niveau -> ESP32-S3 GPIO18 (RX) |
| RX | ESP32-S3 GPIO17 (TX), avec adaptation si nécessaire |
| GND | GND logique commun |
| 5 V | alimentation 5 V conforme au module |

### Important — niveaux logiques

L'ESP32-S3 est un composant 3,3 V et ses GPIO ne doivent pas recevoir directement un niveau 5 V non compatible.

Pour le prototype : mesurer le niveau logique TX du PZEM avant branchement. Si le signal est 5 V, utiliser une adaptation 5 V -> 3,3 V avant GPIO18. Pour le PCB final, prévoir une adaptation de niveau dédiée plutôt que de dépendre d'une tolérance non garantie.

## Partie secteur et pince de courant

Le PZEM mesure une tension secteur potentiellement dangereuse. Les raccordements L/N et la pince de courant doivent être réalisés hors tension par une personne habilitée, avec protections et distances d'isolement adaptées.

La pince de courant se place autour d'un seul conducteur actif, pas autour de la phase et du neutre simultanément.

Architecture fonctionnelle :

```text
Réseau AC
   |
   +---- L/N ----------> PZEM-004T mesure tension
   |
   +---- conducteur ----[ pince CT ]----> chargeur VE

PZEM UART isolé/basse tension
   |
   +---- TX -> adaptation -> ESP32 RX GPIO18
   +---- RX <- adaptation <- ESP32 TX GPIO17
   +---- GND ---------------- ESP32 GND logique
```

## Placement dans la borne

Pour le PCB VE-SCOPE Core :

- séparer physiquement la zone secteur de la zone SELV/basse tension ;
- ne pas faire passer les pistes UART/Wi-Fi près des conducteurs de puissance ;
- conserver l'antenne ESP32 éloignée des masses métalliques et convertisseurs à découpage ;
- filtrer l'alimentation 5 V / 3,3 V ;
- prévoir protections ESD/EMI sur les connecteurs accessibles ;
- utiliser des borniers et connecteurs détrompés ;
- documenter le sens de la pince de courant et les connexions L/N.

## Séquence de mise au point recommandée

1. ESP32-S3 seul, USB série ;
2. test UART avec PZEM alimenté correctement ;
3. lecture tension secteur sans charge ;
4. ajout d'une charge faible connue ;
5. comparaison avec multimètre/pince ampèremétrique de référence ;
6. test MQTT vers Mosquitto ;
7. comparaison Supervisor / instrument de référence ;
8. seulement ensuite intégration mécanique dans la borne.
