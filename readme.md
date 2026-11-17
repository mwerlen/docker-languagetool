<!-- SPDX-License-Identifier: LGPL-3.0-or-later -->

# Introduction

[LanguageTool] is an Open Source proof­reading software for English, French,
German, Polish, and more than 20 other languages.

You can use the LanguageTools with a [firefox-plugin].

This is a Dockerfile to get the languagetools running on a system without java.

[LanguageTool]: https://www.languagetool.org/
[firefox-plugin]: https://addons.mozilla.org/firefox/addon/languagetool

# Usage

The Server is running on port 8081, this port should exposed.

    $ docker pull ghcr.io/mwerlen/docker-languagetool
    [...]
    $ docker run --rm -p 8081:8081 ghcr.io/mwerlen/docker-languagetool

Or you run it in background via `-d`-option.

Run with no minimum rights and RAM
```
docker run --name languagetool \
                        --cap-drop=ALL \
                        --user=65534:65534 \
                        --read-only \
                        --tmpfs /tmp \
                        -p 127.0.0.1:8081:8081 \
                        --memory 1g --memory-swap 1g \
                        -e JAVAOPTIONS="-XX:MaxRAMPercentage=60" \
                        ghcr.io/mwerlen/docker-languagetool:latest
```

Route information can be found at https://languagetool.org/http-api/swagger-ui/#/default, an easy route to test that it's running is `/v2/languages`.

## Server configuration

The server is started with `--config`, built from [misc/server.properties](misc/server.properties).
It currently disables these rules:

    disabledRuleIds=DASH_RULE

A copy is bundled in the image as the default. To change it without
rebuilding, mount your own file on `/config/server.properties` and restart
the container:

    docker run ... -v `pwd`/misc/server.properties:/config/server.properties:ro ...

Any `LT_<key>=<value>` environment variable is appended to it and overrides
the file's value, e.g. `-e LT_disabledRuleIds=DASH_RULE,WHITESPACE_RULE`.
Available keys are listed by `HTTPServer --help`.

## Running locally with make

    make build    # build the local image
    make run      # download en/fr ngrams once, start the container (restarts at boot)
    make restart  # apply changes made to misc/server.properties

`make run` mounts `misc/server.properties`, so editing it and running
`make restart` is enough. `NAME`, `PORT` and `NGRAMS_DIR` can be overridden,
e.g. `make run PORT=8082`.

## ngram support

To support [ngrams] you need an additional volume or directory mounted to the
`/ngrams` directory. For that add a `-v` to the `docker run`-command.

    docker run ... -v /path/to/ngrams:/ngrams ...

[ngrams]: https://dev.languagetool.org/finding-errors-using-n-gram-data


Several languages can be installed side by side: each archive extracts into
its own sub-directory (`ngrams/en`, `ngrams/fr`, ...), and LanguageTool picks
the right one for the checked language.

Download English ngrams (~9 GB zipped, ~15 GB extracted) with the commands:

    mkdir -p ngrams
    wget https://languagetool.org/download/ngram-data/ngrams-en-20150817.zip
    (cd ngrams && unzip ../ngrams-en-20150817.zip)
    rm -f ngrams-en-20150817.zip

Download French ngrams (~2 GB zipped) with the commands:

    mkdir -p ngrams
    wget https://languagetool.org/download/ngram-data/ngrams-fr-20150913.zip
    (cd ngrams && unzip ../ngrams-fr-20150913.zip)
    rm -f ngrams-fr-20150913.zip

Other languages are listed at https://languagetool.org/download/ngram-data/.


One can use them using web browser plugin "Local server (localhost)" setting by running:

    docker run -d --name languagetool -p 127.0.0.1:8081:8081 -v `pwd`/ngrams:/ngrams:ro --restart=unless-stopped ghcr.io/mwerlen/docker-languagetool

### Memory with ngrams

Loading ngrams needs much more memory than the minimal example above: with
English and French ngrams, the live heap is about 520 MB and the container
uses about 1.2 GB in total, so a `--memory 1g` limit gets the JVM OOM-killed
on the first check. Size the heap explicitly instead of limiting the
container:

| ngrams installed | `JAVAOPTIONS`          |
|------------------|------------------------|
| French only      | `-Xms256m -Xmx614m`    |
| English + French | `-Xms512m -Xmx1g`      |

    docker run -d --name languagetool -p 127.0.0.1:8081:8081 \
        -v `pwd`/ngrams:/ngrams:ro --restart=unless-stopped \
        -e JAVAOPTIONS="-Xms512m -Xmx1g" \
        ghcr.io/mwerlen/docker-languagetool

If you still want a container limit as a safety net, keep at least ~700 MB
above `-Xmx` (e.g. `--memory 2g` with `-Xmx1g`).
