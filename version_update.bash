#!/bin/bash
set -e

# Chemin vers ton fichier constants.dart
CONSTANTS_FILE="/data/flutter/scrabble_chen/lib/constants.dart"

# Récupération de la dernière version via ton script
VERSION=$(./version_last.bash)

if [ -z "$VERSION" ]; then
  echo "❌ ERREUR : last_version.bash n'a retourné aucune version."
  exit 1
fi

# Mise à jour de la constante dans constants.dart
sed -i "s/^const String version = \".*\";/const String version = \"$VERSION\";/" "$CONSTANTS_FILE"

echo "✅ constants.dart mis à jour avec version = $VERSION"
