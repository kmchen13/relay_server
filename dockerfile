 
# Image Dart officielle
FROM dart:stable AS build

# Copier les sources
WORKDIR /app
COPY . .

# Résoudre les dépendances
RUN dart pub get

# Build du serveur en snapshot
RUN dart compile exe bin/relay_server.dart -o bin/server

# Runtime minimal
FROM debian:bullseye-slim
WORKDIR /app

# Installer libc pour Dart
RUN apt-get update && apt-get install -y libstdc++6 ca-certificates && rm -rf /var/lib/apt/lists/*

# Copier le serveur compilé
COPY --from=build /app/bin/server /app/server

# Exposer le port
EXPOSE 8080

# Commande de lancement
CMD ["./server"]
