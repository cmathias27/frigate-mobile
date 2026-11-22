# 0002 — Fonctions selon les capacités du serveur, réglages optionnels

**Statut** : Décidé (22 novembre 2026)

## Contexte

Les serveurs Frigate sont configurés très différemment : avec ou sans détection d'objets, reconnaissance des visages, plaques, PTZ, caméras qui acceptent ou non le son envoyé (« Parler »). Le premier serveur visé tourne en **mouvement seul**, sans détection d'objets, sur une machine sans carte graphique. L'application doit rester utile dans ce cas et suivre le serveur quand il évolue, sans nouvelle version.

## Décision

1. **Aucune fonction supposée.** Au démarrage et à chaque reconnexion, l'application lit `GET /api/config`, `GET /api/go2rtc/streams` et `GET /api/version` et en tire les capacités du serveur et de chaque caméra (`app/lib/core/frigate/capabilities.dart`). Chaque écran affiche ou masque ses commandes d'après elles :
   - détection d'objets coupée : la chronologie et la liste montrent les **passages de mouvement** ; les alertes et détections apparaissent dès que Frigate les produit ;
   - **Parler** : proposé sur **toute caméra** dont un flux go2rtc accepte du son (`audio, sendonly`), pas seulement le portier ;
   - **PTZ** : seulement si la caméra a un hôte ONVIF ;
   - visages, plaques, recherche, descriptions : seulement si Frigate les active.
2. **Réglages optionnels plutôt que valeurs figées.** Chaque comportement qui dépend des goûts ou du matériel a une valeur par défaut raisonnable et un réglage, général puis par caméra quand c'est utile :
   - mode de direct (automatique, WebRTC, RTSP, images) et qualité principale ou secondaire ;
   - seuil de mouvement (automatique d'après le bruit habituel de la caméra, ou réglé), durée minimale d'un passage, fusion des passages proches ;
   - cible des boutons « préc. / suiv. » (mouvement, détections ou les deux ; caméra en lecture ou toutes) ;
   - Parler : activé partout où c'est possible par défaut, désactivable par caméra, et forçable pour une caméra que go2rtc ne signale pas ;
   - groupes, ordre et caméras masquées ; plusieurs serveurs ; adresse locale et distante.
3. Un réglage absent d'une ancienne version prend sa valeur par défaut : on n'efface jamais les réglages lors d'une mise à jour.

## Conséquences

- Activer une fonction dans Frigate la fait apparaître dans l'application après reconnexion.
- Les tests des capacités utilisent des réponses de Frigate réelles, anonymisées.
