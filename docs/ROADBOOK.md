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
- [ ] Direct en grille (1, 4, 9), vignettes `latest.jpg`
- [ ] Plein écran : WebRTC go2rtc, repli RTSP ou images, photo
- [ ] Chronologie : bande « toutes les caméras » et bande « caméra en lecture », tête de lecture commune, zoom 1 h / 6 h / 24 h / tout
- [ ] Passages de mouvement : seuil automatique par caméra, durée minimale, fusion ; boutons précédent / suivant
- [ ] Calendrier de tout l'historique, saut à une date et une heure
- [ ] Mise à jour depuis l'application, note de version, « Nouveautés »

## 0.2 — Liste et réglages fins

- [ ] Onglet Alertes : passages de mouvement, puis alertes et détections si Frigate les produit
- [ ] Export d'un extrait, photo
- [ ] Réglages : seuils par caméra, groupes et ordre, qualité, cible de précédent / suivant

## 0.3 — À distance et notifications

- [ ] Accès distant par proxy HTTPS (Caddy), bascule automatique local / distant
- [ ] Relais de notifications (conteneur optionnel) et notifications avec image
- [ ] Mode maison

## 0.4 — Son et confort

- [ ] Écouter et **Parler** sur toutes les caméras qui le permettent (réglage général et par caméra)
- [ ] Widgets Android
- [ ] PTZ, visages, plaques, recherche : seulement quand Frigate les active
