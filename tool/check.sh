#!/usr/bin/env bash
# Same checks as the CI, to run before every push.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n== %s\n' "$1"; }

step "Dépendances"
(cd app && flutter pub get >/dev/null)

step "Localisation à jour (flutter gen-l10n)"
(cd app && flutter gen-l10n >/dev/null)
git diff --exit-code --stat -- app/lib/l10n/app_localizations* \
  || { echo "Traductions générées non committées : committez-les." >&2; exit 1; }
untracked=$(git ls-files --others --exclude-standard -- app/lib/l10n)
[[ -z $untracked ]] \
  || { echo "Traductions générées non suivies : $untracked" >&2; exit 1; }

step "Version et notes de version"
./tool/release_notes.sh "$(sed -n 's/^version: \([0-9.]*\).*/\1/p' app/pubspec.yaml)" >/dev/null

step "Formatage"
(cd app && dart format --output=none --set-exit-if-changed lib test)

step "Analyse"
(cd app && flutter analyze --fatal-infos)

step "Tests"
(cd app && flutter test)

printf '\nTout est vert.\n'
