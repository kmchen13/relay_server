```dockerfile
# Image Dart officielle
FROM dart:stable AS build

# Copier les sources
WORKDIR /app
COPY . .

# Résoudre les dépendances
RUN dart pub get

# Build du serveur en snapshot
RUN dart compile exe lib/relay_server.dart -o bin/server

# Runtime minimal
FROM debian:bookworm-slim
WORKDIR /app

# Installer les bibliothèques nécessaires à Dart
RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copier le serveur compilé
COPY --from=build /app/bin/server /app/server

# Exposer le port
EXPOSE 8080

# Commande de lancement
CMD ["./server"]
```