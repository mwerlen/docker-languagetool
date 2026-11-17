# SPDX-License-Identifier: LGPL-3.0-or-later

# VERSION, shared with docker compose
include .env

IMAGENAME := ghcr.io/mwerlen/docker-languagetool
BUILDARG_VERSION := --build-arg VERSION=$(VERSION)
BUILDARG_PLATFORM := --platform linux/amd64,linux/arm64/v8,linux/arm/v7

# Read by compose.yaml
export NGRAMS_DIR ?= $(CURDIR)/ngrams
export PORT ?= 8081

NGRAMS_URL := https://languagetool.org/download/ngram-data
NGRAMS_DATE_en := 20150817
NGRAMS_DATE_fr := 20150913

envout:
	@echo "VERSION=$(VERSION)"
	@echo "BUILDARG_VERSION=$(BUILDARG_VERSION)"
	@echo "IMAGENAME=$(IMAGENAME)"
	@echo "BUILDARG_PLATFORM=$(BUILDARG_PLATFORM)"

prepare:
	sudo apt-get -qq -y install curl

# Local image, for the current platform only
build:
	docker compose build

# Check that the image builds on every published platform (CI, needs QEMU)
build-multiarch:
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):latest .

# Download and unpack the ngrams of one language, once
# (en: ~9 GB zipped, ~15 GB extracted; fr: ~1.8 GB zipped)
.PHONY: ngrams-en ngrams-fr
ngrams-en: $(NGRAMS_DIR)/en
ngrams-fr: $(NGRAMS_DIR)/fr

$(NGRAMS_DIR)/%:
	mkdir -p $(NGRAMS_DIR)
	curl -fL "$(NGRAMS_URL)/ngrams-$*-$(NGRAMS_DATE_$*).zip" -o "$@.zip"
	rm -rf "$@.tmp"
	unzip -q "$@.zip" -d "$@.tmp"
	mv "$@.tmp/$*" "$@"
	rm -rf "$@.tmp" "$@.zip"

# Build if needed and start the container, recreated only when the image or
# compose.yaml changed. It restarts automatically with the Docker daemon.
.PHONY: run
run:
	docker compose up -d --build
	@echo ":: LanguageTool is available at http://localhost:$(PORT) (check: curl http://localhost:$(PORT)/v2/languages)"

# Apply changes made to misc/server.properties or to the ngrams
.PHONY: restart
restart:
	docker compose restart

.PHONY: stop
stop:
	docker compose down

# Tests run in a separate compose project, without ngrams, so they do not
# touch a running instance; TEST_PORT can be changed if 8081 is taken
TEST_PORT ?= 8081
TEST_COMPOSE := PORT=$(TEST_PORT) NGRAMS_DIR=$(CURDIR)/.ngrams-empty docker compose -p languagetool-test

test: test-cleanup.1
test: test-start
test: test-run-test-lang
test: test-run-test-en
test: test-run-test-fr
test: test-cleanup.2

test-start:
	@echo ""
	mkdir -p .ngrams-empty
	$(TEST_COMPOSE) up -d --build
	sleep 6

test-run-test-lang:
	@echo ""
	curl \
		-X GET \
		--header 'Accept: application/json' \
		'http://localhost:$(TEST_PORT)/v2/languages'

test-run-test-en:
	@echo ""
	curl \
		-X POST \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--header 'Accept: application/json' \
		-d 'text=hello%20woorld&language=en-US&motherTongue=de-DE&enabledOnly=false' \
		'http://localhost:$(TEST_PORT)/v2/check'

test-run-test-fr:
	@echo ""
	curl -X POST \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--header 'Accept: application/json' \
		-d 'text=hello%20woorld&language=fr&motherTongue=de-DE&enabledOnly=false' \
		'http://localhost:$(TEST_PORT)/v2/check'

.PHONY: test-cleanup
test-cleanup.%:
	@echo ""
	-$(TEST_COMPOSE) down

.PHONY: tag
tag: tag-push

.PHONY: tag-push
tag-push:
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):latest . --push
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):$(VERSION) . --push
