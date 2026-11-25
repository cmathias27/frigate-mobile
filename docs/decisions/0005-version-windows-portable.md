# 0005 — Version Windows portable, sans installation

**Statut** : Décidé (25 novembre 2026)

## Contexte

L'utilisateur veut aussi l'application sur un PC Windows, **sans installation**. La décision 0001 prévoyait Android d'abord et d'autres systèmes plus tard, avec le même code Flutter.

## Décision

1. **Même code, même dépôt** : le dossier `app/windows/` est ajouté et la CI compile la version Windows à chaque pull request, comme l'APK.
2. **Archive zip** `frigate-mobile-X.Y.Z-windows.zip`, jointe à chaque version GitHub à côté de l'APK et comptée dans `SHA256SUMS`. On la décompresse où l'on veut puis on lance `frigate_mobile.exe` : pas d'installateur, pas de droits administrateur.
3. **Lecture des enregistrements** : `video_player` n'a pas de lecteur Windows. `video_player_media_kit` (licence MIT, libmpv) prend sa place sous Windows seulement ; Android garde son lecteur. Le direct reste en WebRTC (`flutter_webrtc` gère Windows).
4. **Mise à jour** : sous Windows, l'application vérifie la même version GitHub, montre la note, puis **ouvre le téléchargement de l'archive dans le navigateur** (adresse `github.com` seulement). On ferme l'application et on décompresse la nouvelle archive à la place de l'ancienne. Pas de remplacement automatique de l'exécutable : il faudrait un programme d'aide qui écrive dans le dossier de l'application.
5. **Connexion et réglages** restent dans le stockage sécurisé de Windows (profil de l'utilisateur), pas dans le dossier de l'application : une nouvelle archive les retrouve. Supprimer le dossier ne les efface donc pas.
6. **Non signée** : l'exécutable n'a pas de signature Authenticode (payante). Windows SmartScreen peut avertir au premier lancement ; l'empreinte de `SHA256SUMS` permet de vérifier l'archive.

## Conséquences

- Les fonctions propres à Android (installateur d'APK, permission d'installer, audio « communication » pour Parler) sont sans effet sous Windows, sans erreur.
- Une fonction ajoutée doit fonctionner sur les deux systèmes ou être masquée là où elle ne fonctionne pas.
- La compilation Windows prend plusieurs minutes de CI en plus par pull request.
