# 0004 — Connexion authentifiée et sécurité

**Statut** : Décidé (22 novembre 2026)

## Contexte

Frigate expose deux ports : 5000, **sans authentification** et avec les droits administrateur, prévu pour le réseau interne ; 8971, avec identifiant, mot de passe et jeton JWT.

## Décision

1. L'application parle **uniquement au port authentifié** (8971 ou l'adresse HTTPS d'un proxy devant lui), avec `POST /api/login` puis le jeton `frigate_token`. Elle n'utilise jamais le port 5000.
2. **Deux adresses par serveur** : locale et distante. L'application choisit selon le réseau (réglage), et peut forcer l'une ou l'autre.
3. Le jeton et le mot de passe sont gardés dans le stockage sécurisé du téléphone, exclus des sauvegardes Android. Verrouillage par empreinte en option.
4. Certificat auto-signé de Frigate accepté **seulement** sur l'adresse locale et après confirmation de son empreinte par l'utilisateur ; l'adresse distante exige un certificat valide.
5. **Accès distant** : par un proxy HTTPS (Caddy, comme OwnCoffer) devant le port 8971. Le direct WebRTC depuis l'extérieur demandera en plus le port 8555 ou un repli (RTSP ou images) ; traité avec la configuration de l'accès distant.
6. Aucune télémétrie, aucun appel réseau autre que le serveur Frigate et la vérification des mises à jour (décision 0003).

## Conséquences

- Les tests de connexion utilisent un faux serveur, jamais de vrais identifiants.
- Aucune adresse, aucun identifiant ni aucune image de caméra réelle dans le dépôt, les tests ou les issues.
