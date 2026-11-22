#!/usr/bin/env bash
# Prints the CHANGELOG.md section of a version (decision 0003): it becomes
# the GitHub release notes, which the app shows before installing an update.
# Fails when the section is missing or empty, so no version ships without
# its notes.
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:?usage: tool/release_notes.sh X.Y.Z}
version=${version#v}

notes=$(awk -v v="$version" '
  /^## / { if (found) exit; found = ($2 == v || $2 == "[" v "]") ; next }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')

if [[ -z ${notes//[[:space:]]/} ]]; then
  echo "CHANGELOG.md : aucune note pour la version $version (section « ## $version »)." >&2
  exit 1
fi
printf '%s\n' "$notes"
