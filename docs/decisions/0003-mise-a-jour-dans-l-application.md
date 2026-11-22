# 0003 — Mise à jour depuis l'application, avec note de version

**Statut** : Décidé (22 novembre 2026)

## Contexte

L'application n'est pas sur le Play Store. Sans mécanisme intégré, chaque version obligerait à aller chercher l'APK sur GitHub. Chaque version doit aussi dire ce qui change.

## Décision

1. **Une version = une étiquette `vX.Y.Z`** sur `main`. La CI vérifie que l'étiquette correspond à `app/pubspec.yaml`, compile l'APK signé et crée la version GitHub avec l'APK, `SHA256SUMS` et la **note de version** tirée de la section `## X.Y.Z` de `CHANGELOG.md` (`tool/release_notes.sh`). Pas de note, pas de version : `tool/check.sh` et la CI échouent.
2. **Clé de signature unique**, gardée hors du dépôt et dans les secrets GitHub (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`). Elle n'est **jamais régénérée** : Android refuse d'installer une mise à jour signée par une autre clé. Une étiquette sans clé configurée échoue au lieu de publier un APK de débogage.
3. **Dans l'application** (module `features/update`, à partir de la 0.1) :
   - vérification de `releases/latest` au plus une fois par jour au démarrage, et à la demande dans Plus → Mises à jour ; désactivable ;
   - si une version plus récente existe : fiche avec le numéro et la note de version, « Installer » ou « Plus tard » ;
   - téléchargement de l'APK, **vérification de son empreinte SHA-256** avec `SHA256SUMS`, puis ouverture de l'installateur Android (autorisation « installer des applications inconnues » demandée une fois, avec explication) ;
   - au premier lancement d'une nouvelle version : « Nouveautés » une fois ; l'historique des notes reste consultable dans Plus → À propos.
4. Le seul appel réseau hors du serveur Frigate est cette vérification vers GitHub, faite seulement si l'utilisateur la laisse activée. Aucune télémétrie.

## Conséquences

- Publier : mettre à jour `CHANGELOG.md` et `version:` de `app/pubspec.yaml`, fusionner, puis poser l'étiquette.
- L'APK installé à la main avant la première version signée devra être désinstallé une fois.
