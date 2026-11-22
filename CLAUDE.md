# CLAUDE.md — consignes pour Claude Code

## Le projet

Frigate Mobile : application Android libre (AGPL-3.0) pour Frigate NVR, qui reprend l'interface et les fonctions de DS cam de Synology.

- Écrans validés : `docs/maquettes.html`.
- Ordre de réalisation : `docs/ROADBOOK.md`.
- Décisions : `docs/decisions/` — à respecter ; pour en changer une, écrire une nouvelle décision.

## Règles impératives

- **Rien de figé pour un serveur** (décision 0002) : toute fonction dépend des capacités lues (`app/lib/core/frigate/capabilities.dart`) ; tout comportement discutable a une valeur par défaut et un réglage optionnel.
- **Port authentifié seulement** (décision 0004) : jamais le port 5000 de Frigate dans l'application.
- **Aucune donnée réelle dans le dépôt** : ni adresse, ni identifiant, ni image de caméra, ni nom de personne. Réponses de Frigate anonymisées dans les tests.
- **Aucune télémétrie** ; seuls appels réseau : le serveur Frigate et la vérification des mises à jour (désactivable).
- **Bilingue** : aucun texte d'interface en dur, tout passe par `app/lib/l10n/app_fr.arb` et `app_en.arb`.
- **Clé de signature Android** : jamais régénérée (décision 0003).
- Toute dépendance ajoutée doit être compatible AGPL-3.0.

## Instance Frigate de l'utilisateur

`/opt/docker/frigate` est son installation réelle. Ne pas modifier son `docker-compose.yml` ni `config/config.yaml` sans son accord explicite ; sauvegarder le fichier avant toute modification acceptée. Lecture de l'API locale permise pour vérifier un comportement, sans jamais copier d'image, d'adresse ou d'identifiant dans le dépôt.

## Façon de travailler

- Une branche (`feature/…`, `fix/…`, `docs/…`) = une pull request vers `main`, jamais empilées.
- Commits *Conventional Commits*, signés DCO (`git commit -s`).
- Code et commentaires techniques en anglais ; documentation et textes à l'utilisateur en français.
- Avant chaque push : `./tool/check.sh`.
- Publier une version : section `## X.Y.Z` dans `CHANGELOG.md` (écrite pour l'utilisateur), `version:` de `app/pubspec.yaml`, fusion, puis étiquette `vX.Y.Z` sur `main`.
- Après chaque tâche terminée, cocher la case dans `docs/ROADBOOK.md`.
