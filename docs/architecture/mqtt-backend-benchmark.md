# Benchmark MQTT — HydroPilot, KËR NJOMBOOR et VE-SCOPE

## Objectif

Capitaliser sur les architectures MQTT déjà éprouvées dans les projets HydroPilot et KËR NJOMBOOR afin d'éviter de reconstruire une chaîne de communication différente pour VE-SCOPE.

## Enseignements HydroPilot

HydroPilot a validé une chaîne complète :

```text
ESP32 -> Mosquitto -> backend -> base de données / moteur d'alertes -> WebSocket -> application
```

Les points réutilisés sont :

- séparation entre le broker MQTT et l'interface utilisateur ;
- topics versionnés par appareil ;
- télémétrie en QoS 0 ;
- messages importants en QoS 1 ;
- état de disponibilité et LWT ;
- backend chargé de valider, historiser et redistribuer les messages ;
- WebSocket pour pousser les mises à jour vers l'interface sans polling ;
- informations de santé du microcontrôleur dans la télémétrie ou le diagnostic ;
- reconnexion automatique du microcontrôleur et du backend.

## Enseignements KËR NJOMBOOR

KËR NJOMBOOR confirme l'intérêt d'une infrastructure découplée comprenant :

```text
Mosquitto + backend applicatif + PostgreSQL + reverse proxy
```

Cette organisation permet de faire évoluer indépendamment les appareils, le backend et les interfaces Web/mobile. Elle facilite aussi le passage d'un environnement local à un serveur distant.

## Choix retenu pour VE-SCOPE

L'architecture cible est :

```text
PZEM / JK BMS / chargeur
          |
          v
    VE-SCOPE Core
          |
        MQTT
          v
      Mosquitto
          |
          v
    VE-SCOPE Hub
      |       |
      |       +----> persistance / alertes (étape suivante)
      v
   WebSocket + REST
          |
          v
 VE-SCOPE Supervisor
```

Le navigateur ne se connecte pas directement au broker MQTT. Cette règle permet de centraliser l'authentification, les droits, la validation des schémas, l'historisation et les alarmes dans VE-SCOPE Hub.

## Politique QoS retenue

| Flux | QoS | Retain |
|---|---:|---:|
| status | 1 | oui |
| telemetry/ac | 0 | non |
| session/live | 0 | non |
| session/summary | 1 | non |
| alerts | 1 | non |
| diagnostics | 0 | non |
| bms | 0 | non |
| charger | 0 | non |

## Disponibilité et reconnexion

VE-SCOPE Core doit publier un état `online` après connexion et configurer un Last Will and Testament `offline`. Le backend et le Supervisor doivent considérer une donnée comme périmée lorsque son âge dépasse le seuil défini, et non comme une valeur nulle valide.

Le client Supervisor tente le WebSocket VE-SCOPE Hub avec backoff progressif. Si aucune donnée Hub récente n'est disponible en développement, l'interface conserve le mode simulation afin de ne pas bloquer le travail UI.

## Étapes suivantes

1. valider la chaîne locale Mosquitto -> Hub -> WebSocket ;
2. connecter le simulateur au broker ;
3. afficher explicitement dans Supervisor si la source est `SIMULATION` ou `HUB` ;
4. ajouter PostgreSQL pour les sessions, télémétries et événements ;
5. intégrer le moteur d'alarmes ;
6. remplacer le simulateur par VE-SCOPE Core réel ;
7. sécuriser le broker et le Hub pour le déploiement distant.
