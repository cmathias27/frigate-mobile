# Notes de version

Chaque section devient la note de la version publiée sur GitHub, que
l'application affiche avant d'installer une mise à jour et dans
« Nouveautés » après l'installation (décision 0003). Écrire pour
l'utilisateur : ce qui change pour lui, pas comment c'est codé.

## 0.1.1

Corrections après les premiers essais, et premières fonctions de la
version 0.2.

- La chronologie s'affiche de nouveau : ses bandes étaient invisibles
  sur toutes les caméras.
- Une caméra dont la vidéo ne passe pas ou reste figée bascule seule sur
  un autre flux, souvent plus léger, que le téléphone sait lire ; en
  dernier recours elle montre des images.
- Direct : nouvelle disposition automatique, choisie par défaut. Toutes
  les caméras tiennent sur un écran, aussi grandes que possible,
  téléphone debout ou couché ; au-delà, elles se répartissent sur
  plusieurs pages. Les dispositions 1, 4 et 9 restent proposées, et le
  choix est gardé.
- Connexion : l'application passe seule de l'adresse locale à l'adresse
  distante quand l'une ne répond pas.
- Onglet Alertes : les passages de mouvement jour par jour, les nouveaux
  depuis votre dernière visite mis en évidence ; un toucher ouvre le
  passage dans la chronologie.
- Chronologie : export d'un extrait de 2 s à 10 min ou d'une photo de
  l'image enregistrée, rangés dans l'album « Frigate » ou partagés.
- Boutons « précédent » et « suivant » : sur la caméra en lecture, ou
  sur toutes les caméras au choix (choix gardé).

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
