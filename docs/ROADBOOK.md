# Feuille de route

Une version par étape. Chaque étape se termine par une étiquette `vX.Y.Z` et une note de version (décision 0003).

## 0.0.x — Squelette

- [x] Projet Flutter Android, modules, français et anglais
- [x] Lecture des capacités du serveur et des caméras (décision 0002)
- [x] CI : analyse, tests, APK signé, version GitHub avec note sur étiquette
- [x] Clé de signature créée et secrets GitHub posés

## 0.1 — Direct, chronologie du mouvement, mises à jour

- [x] Connexion : adresse locale et distante, `POST /api/login`, jeton gardé en sécurité
- [x] Lecture des capacités au démarrage, fonctions affichées selon le serveur
- [x] Direct en grille (1, 4, 9), pages, vignettes `latest.jpg` rafraîchies seulement à l'écran
- [x] Plein écran en images : pleine résolution chaque seconde, zoom, glisser d'une caméra à l'autre
- [x] Plein écran vidéo : WebRTC go2rtc, repli en images, son si le flux en a, choix du flux
- [x] Photo depuis le plein écran : image vidéo à sa résolution, album « Frigate », partage
- [x] Chronologie : bande « toutes les caméras » et bande « caméra en lecture », tête de lecture commune, zoom 1 h / 6 h / 24 h / tout, lecture des enregistrements (HLS par relais local)
- [x] Passages de mouvement : seuil automatique par caméra, durée minimale, fusion ; boutons précédent / suivant
- [x] Calendrier de tout l'historique, saut à une date et une heure
- [x] Mise à jour depuis l'application, note de version, « Nouveautés »

## 0.2 — Liste et réglages fins

- [x] Onglet Alertes : passages de mouvement par jour, nouveaux depuis la dernière visite, ouverture dans la chronologie
- [x] Onglet Alertes : alertes et détections quand Frigate les produit (`/api/review`), marquer vu
- [x] Export d'un extrait, photo (chronologie : extrait de 2 s à 10 min, enregistré dans l'album Frigate ou partagé ; photo de l'image enregistrée)
- [x] Passage préc. et suiv. sur la caméra lue, ou sur toutes les caméras (choix gardé)
- [x] Vidéo figée ou impossible : bascule seule sur le flux suivant de la caméra (sous-flux lus par Frigate compris), puis images
- [x] Chronologie : enregistrement illisible par le téléphone (image trop grande pour son décodeur) ou figé → lecture en images enregistrées, vidéo réessayable
- [x] Direct en disposition automatique : toutes les caméras sur un écran tant qu'elles restent lisibles, vignettes à la taille de l'écran, debout ou couché (choix de disposition gardé)
- [x] Chronologie qui s'ouvre sur le direct de la caméra (flux léger d'abord) ; glisser en arrière lit l'enregistrement, bouton « Direct » pour revenir
- [ ] Réglages : seuils par caméra, groupes et ordre, qualité, cible de précédent / suivant

## 0.3 — À distance et notifications

- [ ] Accès distant par proxy HTTPS (Caddy), bascule automatique local / distant
- [ ] Relais de notifications (conteneur optionnel) et notifications avec image
- [ ] Mode maison

## 0.4 — Son et confort

- [ ] Écouter et **Parler** sur toutes les caméras qui le permettent (réglage général et par caméra)
- [ ] Widgets Android
- [ ] PTZ, visages, plaques, recherche : seulement quand Frigate les active
