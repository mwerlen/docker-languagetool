#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Run LanguageTool locally with English and French ngrams.
# The container restarts automatically with the Docker daemon (i.e. at boot).

set -euo pipefail

IMAGE=${IMAGE:-ghcr.io/mwerlen/docker-languagetool:latest}
NAME=${NAME:-languagetool}
PORT=${PORT:-8081}
NGRAMS_DIR=${NGRAMS_DIR:-"$(cd "$(dirname "$0")" && pwd)/ngrams"}
NGRAMS_URL=https://languagetool.org/download/ngram-data
NGRAMS=(en-20150817 fr-20150913)

mkdir -p "$NGRAMS_DIR"

# Download and unpack each ngram archive once (en: ~9 GB, fr: ~1.8 GB zipped)
for ngram in "${NGRAMS[@]}"; do
    lang=${ngram%%-*}
    if [ -d "$NGRAMS_DIR/$lang" ]; then
        echo ":: ngrams '$lang' already present in $NGRAMS_DIR/$lang"
        continue
    fi
    echo ":: downloading ngrams '$lang'"
    curl -fL "$NGRAMS_URL/ngrams-$ngram.zip" -o "$NGRAMS_DIR/ngrams-$ngram.zip"
    unzip -q "$NGRAMS_DIR/ngrams-$ngram.zip" -d "$NGRAMS_DIR"
    rm -f "$NGRAMS_DIR/ngrams-$ngram.zip"
done

echo ":: pulling $IMAGE"
docker pull "$IMAGE"

# Replace any previous container so the latest image and options are used
docker rm -f "$NAME" >/dev/null 2>&1 || true

echo ":: starting container $NAME"
docker run -d --name "$NAME" \
    --restart=unless-stopped \
    -p "127.0.0.1:$PORT:8081" \
    -v "$NGRAMS_DIR":/ngrams:ro \
    "$IMAGE"

echo ":: LanguageTool will be available at http://localhost:$PORT (check: curl http://localhost:$PORT/v2/languages)"
