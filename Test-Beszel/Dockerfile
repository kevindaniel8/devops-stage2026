# Dockerfile personnalisé Beszel avec outils de diagnostic
FROM henrygd/beszel:latest as beszel-base

# Image Alpine avec outils réseau
FROM alpine:latest

# Installation des outils de diagnostic
RUN apk add --no-cache bash curl busybox-extras bind-tools

# Copie du binaire Beszel depuis l'image officielle
COPY --from=beszel-base /beszel /beszel

# Ports exposés
EXPOSE 8090

# Point d'entrée
ENTRYPOINT ["/beszel"]
CMD ["serve", "--http=0.0.0.0:8090"]
