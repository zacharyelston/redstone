# Use the official lldap image as a base
FROM lldap/lldap:stable

# Switch to root user to install packages
USER root

# Install curl using apk package manager
RUN apk add --no-cache curl

# Switch back to the default lldap user
USER lldap
