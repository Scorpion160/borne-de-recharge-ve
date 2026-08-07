# VE-SCOPE Hub

VE-SCOPE Hub est la passerelle entre le broker MQTT et les interfaces de supervision.

Architecture retenue après benchmark des projets HydroPilot et KER NJOMBOOR :

```text
VE-SCOPE Core / simulateur -> Mosquitto -> VE-SCOPE Hub -> WebSocket/REST -> Supervisor
```

Le navigateur n'accède pas directement au broker MQTT. Le Hub centralise la validation du contrat, le dernier état connu et la diffusion temps réel vers l'interface.

## Cibles V0

- ingestion des topics `vescope/+/...` ;
- validation du champ `schema` ;
- état de santé MQTT ;
- dernier état connu par borne ;
- WebSocket par borne ;
- préparation de la persistance PostgreSQL et du moteur d'alarmes.
