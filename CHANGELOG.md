# Notes de version

Chaque section devient la note de la version publiée sur GitHub, que
l'application affiche avant d'installer une mise à jour et dans
« Nouveautés » après l'installation (décision 0003). Écrire pour
l'utilisateur : ce qui change pour lui, pas comment c'est codé.

## 0.1.0

Première version utilisable : regarder ses caméras en direct et revoir
les enregistrements.

- Connexion à votre serveur Frigate par son adresse, avec votre compte ;
  la session reste ouverte en toute sécurité.
- Direct : grille de 1, 4 ou 9 caméras, images rafraîchies seulement
  pour les caméras à l'écran.
- Plein écran : vidéo en temps réel avec le son quand la caméra en a,
  choix du flux, zoom, et passage d'une caméra à l'autre en glissant.
  Si la vidéo ne passe pas, l'application montre des images à la place.
- Photo depuis le plein écran, rangée dans l'album « Frigate » ou
  partagée.
- Chronologie : toutes les caméras sur une bande, celle en lecture sur
  une autre, zoom de 1 h à tout l'historique, lecture des
  enregistrements.
- Passages de mouvement repérés sur la chronologie, avec boutons
  « précédent » et « suivant » pour aller de l'un à l'autre.
- Calendrier de tout l'historique : jours enregistrés en entier ou en
  partie, saut à une date et une heure, raccourcis « Il y a 1 h »,
  « Ce matin », « Hier soir » et « Le plus ancien ».
- Mises à jour depuis l'application : vérification une fois par jour
  (désactivable dans Plus), note de version avant d'installer, et
  « Nouveautés » après la mise à jour.

## 0.0.1

Squelette de l'application, pas encore utilisable avec un serveur Frigate.

- Les quatre onglets de l'application : Direct, Chronologie, Alertes et Plus.
- Interface en français et en anglais, selon la langue du téléphone.
