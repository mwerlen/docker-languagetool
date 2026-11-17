# SPDX-License-Identifier: LGPL-3.0-or-later

include Makefile.version

NAME ?= languagetool
PORT ?= 8081
NGRAMS_DIR ?= $(CURDIR)/ngrams
NGRAMS_URL := https://languagetool.org/download/ngram-data
NGRAMS := en-20150817 fr-20150913
# Mounted into the container: edit it and `make restart`, no rebuild needed
CONFIG := $(CURDIR)/misc/server.properties

envout:
	@echo "VERSION=$(VERSION)"
	@echo "UNPACKED_VERSION=$(UNPACKED_VERSION)"
	@echo "BUILDARG_VERSION=$(BUILDARG_VERSION)"
	@echo "IMAGENAME=$(IMAGENAME)"
	@echo "BUILDARG_PLATFORM=$(BUILDARG_PLATFORM)"

prepare:
	sudo apt-get -qq -y install curl

# Local image, for the current platform only
build: download
	docker buildx build $(BUILDARG_VERSION) --load -t $(IMAGENAME):latest -t $(IMAGENAME):$(VERSION) .

# Check that the image builds on every published platform (CI, needs QEMU)
build-multiarch: download
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):latest .

download: LanguageTool-stable.zip
	-rm -rf LanguageTool-$(VERSION) LanguageTool-$(UNPACKED_VERSION)
	echo ":: unzipping LanguageTool-stable.zip"
	unzip -o LanguageTool-stable.zip 2>&1 1>/dev/null
	@test -f LanguageTool-$(UNPACKED_VERSION)/languagetool-server.jar || \
		{ echo ":: LanguageTool-stable.zip does not contain version $(UNPACKED_VERSION), found: $$(ls -d LanguageTool-*/)"; exit 1; }

LanguageTool-stable.zip:
	curl -fL https://languagetool.org/download/LanguageTool-stable.zip -o LanguageTool-stable.zip

# Download and unpack each ngram archive once (en: ~9 GB, fr: ~1.8 GB zipped)
.PHONY: ngrams
ngrams:
	mkdir -p $(NGRAMS_DIR)
	@for ngram in $(NGRAMS); do \
		lang=$${ngram%%-*}; \
		if [ -d "$(NGRAMS_DIR)/$$lang" ]; then \
			echo ":: ngrams '$$lang' already present in $(NGRAMS_DIR)/$$lang"; \
			continue; \
		fi; \
		echo ":: downloading ngrams '$$lang'"; \
		curl -fL "$(NGRAMS_URL)/ngrams-$$ngram.zip" -o "$(NGRAMS_DIR)/ngrams-$$ngram.zip" && \
		unzip -q "$(NGRAMS_DIR)/ngrams-$$ngram.zip" -d "$(NGRAMS_DIR)" && \
		rm -f "$(NGRAMS_DIR)/ngrams-$$ngram.zip" || exit 1; \
	done

# Run the local image with English and French ngrams and the mounted config.
# The container restarts automatically with the Docker daemon (i.e. at boot).
.PHONY: run
run: ngrams
	-docker rm -f $(NAME) >/dev/null 2>&1
	docker run -d --name $(NAME) \
		--restart=unless-stopped \
		-p 127.0.0.1:$(PORT):8081 \
		-v $(NGRAMS_DIR):/ngrams:ro \
		-v $(CONFIG):/config/server.properties:ro \
		$(IMAGENAME):latest
	@echo ":: LanguageTool will be available at http://localhost:$(PORT) (check: curl http://localhost:$(PORT)/v2/languages)"

# Apply changes made to $(CONFIG)
.PHONY: restart
restart:
	docker restart $(NAME)

test: test-cleanup.1
test: test-start
test: test-run-test-lang
test: test-run-test-en
test: test-run-test-fr
test: test-cleanup.2

test-start:
	@echo ""
	docker run -d --name languagetool -p 8081:8081 \
		-v $(CONFIG):/config/server.properties:ro \
		$(IMAGENAME):latest
	sleep 6

test-run-test-lang:
	@echo ""
	curl \
		-X GET \
		--header 'Accept: application/json' \
		'http://localhost:8081/v2/languages'

test-run-test-en:
	@echo ""
	curl \
		-X POST \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--header 'Accept: application/json' \
		-d 'text=hello%20woorld&language=en-US&motherTongue=de-DE&enabledOnly=false' \
		'http://localhost:8081/v2/check'

test-run-test-fr:
	@echo ""
	curl -X POST \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--header 'Accept: application/json' \
		-d 'text=hello%20woorld&language=fr&motherTongue=de-DE&enabledOnly=false' \
		'http://localhost:8081/v2/check'

.PHONY: test-cleanup
test-cleanup.%:
	@echo ""
	-docker container stop languagetool
	-docker container rm languagetool

.PHONY: tag
tag: tag-push

.PHONY: tag-push
tag-push:
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):latest . --push
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):$(VERSION) . --push
