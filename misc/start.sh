#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later

EXTRAOPTIONS=${EXTRAOPTIONS:-}
JAVAOPTIONS=${JAVAOPTIONS:-}
CONFIG=/tmp/config.properties

if [ -n "$(ls -A /ngrams 2>/dev/null)" ]; then
    EXTRAOPTIONS="${EXTRAOPTIONS} --languageModel /ngrams"
fi

# size the heap from the ngrams to load, unless JAVAOPTIONS is given
# (measured: en+fr live heap ~520 MB, fr only much less, see readme)
if [ -z "$JAVAOPTIONS" ]; then
    if [ -d /ngrams/en ]; then
        JAVAOPTIONS="-Xms512m -Xmx1g"
    elif [ -d /ngrams/fr ]; then
        JAVAOPTIONS="-Xms256m -Xmx614m"
    fi
fi

# start from /config/server.properties when mounted, else from the one
# bundled in the image, then append environment variables starting with
# LT_ (name without the prefix, and value); a key repeated later in the
# file overrides the earlier one
BASE_CONFIG=server.properties
if [ -f /config/server.properties ]; then
    BASE_CONFIG=/config/server.properties
fi
echo "using $BASE_CONFIG"
cp "$BASE_CONFIG" "$CONFIG"
for var in ${!LT_*}; do
  echo "${var#'LT_'}="${!var} >> "$CONFIG"
done
EXTRAOPTIONS="${EXTRAOPTIONS} --config $CONFIG"

echo JAVAOPTIONS=$JAVAOPTIONS
echo config.properties:
cat "$CONFIG"
echo EXTRAOPTIONS=$EXTRAOPTIONS

java ${JAVAOPTIONS} -cp languagetool-server.jar org.languagetool.server.HTTPServer --port 8081 --public --allow-origin '*' ${EXTRAOPTIONS}
