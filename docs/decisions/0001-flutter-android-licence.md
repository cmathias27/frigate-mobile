# 0001 — Application Flutter pour Android, licence AGPL-3.0

**Statut** : Décidé (22 novembre 2026)

## Contexte

L'objectif est une application mobile pour Frigate NVR qui reprend l'interface et les fonctions de DS cam (Synology) : direct en grille, chronologie des enregistrements, alertes, notifications. Les écrans validés sont dans `docs/maquettes.html`.

## Décision

1. **Flutter**, un seul code. **Android d'abord** : iOS demande un Mac pour compiler et un compte Apple payant ; Flutter permettra de l'ajouter plus tard sans réécriture.
2. **Distribution hors magasins** : APK publié en version GitHub par la CI, mis à jour depuis l'application (décision 0003).
3. **Organisation en modules** : `app/lib/core/` (accès à Frigate, capacités, réglages), `app/lib/features/<module>/` (direct, chronologie, alertes, réglages, mise à jour), `app/lib/app/` (thème, navigation). Un module ne dépend pas d'un autre module, seulement de `core/`.
4. **Bilingue** français et anglais : aucun texte d'interface en dur, tout passe par `app/lib/l10n/`.
5. **Licence AGPL-3.0**. Toute dépendance ajoutée doit être compatible.

## Conséquences

- Les tests couvrent en priorité le code sans interface (lecture des réponses de Frigate, calcul des passages de mouvement, comparaison de versions).
- `tool/check.sh` lance les mêmes vérifications que la CI avant chaque envoi.
