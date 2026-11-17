# SPDX-License-Identifier: LGPL-3.0-or-later
FROM docker.io/library/eclipse-temurin:21

# see .env
ARG VERSION

LABEL maintainer="Maxime Werlen <maxime@werlen.fr>"

# Download and unpack in a single layer so the zip is not kept in the image
# (the base image has curl and jar, which unpacks zip files, but no unzip)
RUN curl -fsSL "https://languagetool.org/download/LanguageTool-${VERSION}.zip" -o /tmp/lt.zip \
    && cd /tmp && jar xf lt.zip \
    && mv /tmp/LanguageTool-*/ /LanguageTool \
    && rm -f /tmp/lt.zip

WORKDIR /LanguageTool

COPY misc/start.sh misc/server.properties ./
CMD [ "bash", "start.sh" ]
USER nobody
EXPOSE 8081
