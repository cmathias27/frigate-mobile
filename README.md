# Frigate Mobile

Application Android libre pour [Frigate NVR](https://frigate.video), inspirée de DS cam de Synology : direct en grille, chronologie de tous les enregistrements avec le mouvement et les détections, alertes, notifications.

**État : 0.1.0, direct, chronologie et mises à jour.** Les écrans prévus sont dans [`docs/maquettes.html`](docs/maquettes.html), l'ordre de réalisation dans [`docs/ROADBOOK.md`](docs/ROADBOOK.md).

## Principes

- L'application s'adapte à votre serveur : elle lit ce que Frigate sait faire et n'affiche que les fonctions disponibles (décision 0002). Un serveur en mouvement seul, sans détection d'objets, a quand même une chronologie navigable.
- Connexion uniquement par le port authentifié de Frigate (8971), jamais par le port 5000 (décision 0004).
- Mises à jour depuis l'application, avec la note de chaque version (décision 0003).
- Aucune télémétrie.

## Prérequis côté Frigate

- Frigate 0.14 ou plus récent (testé avec 0.18).
- Port 8971 accessible depuis le téléphone, et un compte Frigate.
- Pour le direct WebRTC : `go2rtc.webrtc.candidates` avec l'adresse locale du serveur et le port 8555, publié en TCP et UDP. Sans cela, le plein écran reste en images.
- Pour le son en direct : WebRTC n'accepte que l'audio Opus, PCMA ou PCMU. Une caméra en AAC n'a pas de son tant que go2rtc ne le convertit pas, par exemple avec une seconde source `ffmpeg:<flux>#audio=opus` dans `go2rtc.streams`. Le bouton Son n'apparaît que sur les flux qui en ont.

## Développement

```sh
cd app
flutter pub get
flutter run
```

Avant chaque envoi : `./tool/check.sh`.

## Licence

AGPL-3.0 (`LICENSE`).
