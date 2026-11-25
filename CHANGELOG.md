# Notes de version

Chaque section devient la note de la version publiée sur GitHub, que
l'application affiche avant d'installer une mise à jour et dans
« Nouveautés » après l'installation (décision 0003). Écrire pour
l'utilisateur : ce qui change pour lui, pas comment c'est codé.

## 0.2.2

Fin de la revue de l'application : heure, démarrage et textes.

- Chronologie : les jours de changement d'heure, les graduations restent
  sur les heures rondes et « jour précédent / suivant » garde la même
  heure.
- Au démarrage, les caméras s'affichent directement dans l'ordre choisi,
  sans montrer un instant les caméras masquées.
- « Nouveautés » et la recherche automatique de mise à jour attendent
  que l'application connaisse sa version.
- Onglet Plus : la durée de conservation affichée tient compte des
  alertes et détections (« Enregistrements conservés jusqu'à … »).
- Textes : vouvoiement partout, espaces insécables (plus de « : » ou de
  « s » seuls en début de ligne), pluriels corrects, badge DIRECT en
  français. En anglais, les jours gardent leur majuscule.

## 0.2.1

Corrections de sécurité et de fiabilité, après une revue complète de
l'application.

- Connexion : le certificat auto-signé de l'adresse locale n'est plus
  accepté d'office. À la première connexion, l'application affiche son
  empreinte SHA-256 et demande de la confirmer. Si le certificat change
  ensuite, elle le signale et demande une nouvelle confirmation.
  **Après la mise à jour, l'application demande de se reconnecter une
  fois pour confirmer l'empreinte.**
- Connexion : seules les adresses https sont acceptées, et le port 5000
  de Frigate (sans authentification) est refusé. Le jeton de connexion
  n'est plus inclus dans les sauvegardes Android.
- Les erreurs s'affichent sur l'écran de connexion, dans la langue du
  téléphone : identifiants refusés, serveur injoignable, certificat
  refusé, session expirée… Quand le serveur est injoignable au
  démarrage, le bouton « Réessayer » rouvre la session sans redemander
  le mot de passe.
- « Actualiser » (onglet Plus) indique si l'actualisation a échoué, et
  pourquoi.
- Chronologie : en paysage, les commandes ne débordent plus de l'écran.
  Changer d'heure ou de caméra pendant le chargement ne laisse plus un
  lecteur ouvert en arrière-plan, et ne fige plus la lecture en images.
- Direct : la vidéo est entièrement libérée en quittant une caméra, ce
  qui économise mémoire et batterie.
- Alertes : une actualisation pendant le chargement des jours précédents
  ne mélange plus les listes. Toucher l'alerte d'une caméra qui
  n'enregistre pas l'indique, au lieu de ne rien faire.
- Premier serveur : plus d'adresse préremplie.

## 0.2.0

Fin de l'étape « liste et réglages fins ».

- Chronologie : elle s'ouvre sur le direct de la caméra, avec la
  pastille « DIRECT ». Glisser la frise en arrière lit l'enregistrement,
  le bouton « Direct » ramène au présent.
- Chronologie : vitesse de lecture des enregistrements, de ×0,5 à ×8,
  gardée d'une fois sur l'autre. Elle vaut aussi pour la lecture en
  images.
- Onglet Alertes : quand Frigate détecte des objets ou des sons, ses
  alertes et détections s'affichent jour par jour, avec un filtre par
  caméra. On les marque vues une à une (glisser), par sélection ou
  toutes d'un coup.
- Nouvel écran **Réglages** (onglet Plus) :
  - caméras : ordre, caméras masquées, seuil de mouvement propre à
    chaque caméra (la valeur automatique reste proposée) ;
  - groupes de caméras, à choisir en haut du direct ;
  - direct : flux ouvert d'abord (principal, léger ou automatique),
    passage aux autres flux en cas d'échec, taille des vignettes ;
  - chronologie : lecture en images si la vidéo échoue, durée minimale
    d'un passage, regroupement des passages proches.

## 0.1.2

- Chronologie : une caméra dont le téléphone ne sait pas lire la vidéo
  (image trop grande pour son décodeur) ou dont la vidéo reste figée est
  lue en images enregistrées, quelques-unes par seconde, au même
  instant. La pastille « Images » sur la vidéo explique pourquoi, donne
  le détail de l'erreur et permet de réessayer la vidéo.

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
