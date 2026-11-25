# Frigate Mobile

Application libre pour Android et Windows, pour [Frigate NVR](https://frigate.video), inspirée de DS cam de Synology : direct en grille, chronologie de tous les enregistrements avec le mouvement et les détections, alertes, son et orientation des caméras.

**État : en développement, versions publiées dans [Releases](https://github.com/cmathias27/frigate-mobile/releases).** Les écrans prévus sont dans [`docs/maquettes.html`](docs/maquettes.html), l'ordre de réalisation dans [`docs/ROADBOOK.md`](docs/ROADBOOK.md).

## Principes

- L'application s'adapte à votre serveur : elle lit ce que Frigate sait faire et n'affiche que les fonctions disponibles (décision 0002). Un serveur en mouvement seul, sans détection d'objets, a quand même une chronologie navigable.
- Connexion uniquement par le port authentifié de Frigate (8971), jamais par le port 5000 (décision 0004).
- Mises à jour depuis l'application, avec la note de chaque version (décision 0003).
- Aucune télémétrie.

## Installation

- **Android** : télécharger `frigate-mobile-X.Y.Z-android.apk` dans la dernière version et l'ouvrir. Les mises à jour se font ensuite depuis l'application.
- **Windows, sans installation** : télécharger `frigate-mobile-X.Y.Z-windows.zip`, le décompresser où vous voulez et lancer `frigate_mobile.exe` dans le dossier « Frigate Mobile ». Windows SmartScreen peut avertir au premier lancement : l'exécutable n'est pas signé (décision 0005). Pour mettre à jour, l'application ouvre le téléchargement de la nouvelle archive ; fermez-la et décompressez la nouvelle à la place de l'ancienne, la connexion et les réglages sont conservés.

Les empreintes de tous les fichiers sont dans `SHA256SUMS`.

## Prérequis côté Frigate

- Frigate 0.14 ou plus récent (testé avec 0.18).
- Port 8971 accessible depuis le téléphone ou le PC, et un compte Frigate. Adresse en `https://` obligatoire ; le port 5000, sans authentification, est refusé.
- Certificat auto-signé de Frigate : accepté seulement sur l'adresse locale, après confirmation de son empreinte SHA-256 à la première connexion (décision 0004). Pour l'afficher sur le serveur, en comparant avec celle montrée par l'application :

  ```sh
  docker exec frigate openssl x509 -noout -fingerprint -sha256 \
    -in /etc/letsencrypt/live/frigate/fullchain.pem
  ```

  L'application la redemande si le certificat change. L'adresse distante exige un certificat valide (Caddy, Let's Encrypt…).
- Pour le direct WebRTC : `go2rtc.webrtc.candidates` avec l'adresse locale du serveur et le port 8555, publié en TCP et UDP. Sans cela, le plein écran reste en images.
- Pour parler aux caméras (bouton « Parler ») : une caméra dont go2rtc propose un retour audio (`audio, sendonly`), par exemple un portier.
- Pour orienter une caméra (bouton « Orienter ») : sa section `onvif` dans la configuration de Frigate.
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
