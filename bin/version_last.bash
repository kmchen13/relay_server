#!/bin/bash
# Récupère la dernière version (numéro au début de ligne)

last_version=$(grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' changelog.txt | tail -n 1)

echo "$last_version"
