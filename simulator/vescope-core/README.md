# Simulateur VE-SCOPE Core

Ce simulateur produit des mesures AC réalistes compatibles avec le contrat MQTT V1 de VE-SCOPE.

## Installation

```bash
cd simulator/vescope-core
python -m venv .venv
```

Sous Windows PowerShell :

```powershell
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Test sans broker MQTT

```bash
python simulator.py --stdout-only
```

Le simulateur écrit alors les messages JSON sur la sortie standard.

## Publication MQTT

Avec un broker local :

```bash
python simulator.py --broker localhost --port 1883
```

Avec authentification :

```bash
python simulator.py --broker 192.168.1.10 --port 1883 --username vescope --password MOT_DE_PASSE
```

Ne jamais enregistrer un vrai mot de passe dans le dépôt.

## Topics publiés

- `vescope/borne-01/status`
- `vescope/borne-01/telemetry/ac`
- `vescope/borne-01/session/live`

Le simulateur sera progressivement enrichi pour générer des anomalies réseau, pertes Modbus, sessions interrompues, alarmes et données JK BMS.
