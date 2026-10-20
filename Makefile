# SPDX-License-Identifier: LGPL-3.0-or-later

include Makefile.version

envout:
	@echo "VERSION=$(VERSION)"
	@echo "UNPACKED_VERSION=$(UNPACKED_VERSION)"
	@echo "BUILDARG_VERSION=$(BUILDARG_VERSION)"
	@echo "IMAGENAME=$(IMAGENAME)"
	@echo "BUILDARG_PLATFORM=$(BUILDARG_PLATFORM)"

prepare:
	sudo apt-get -qq -y install curl

build: download
	docker buildx build $(BUILDARG_VERSION) $(BUILDARG_PLATFORM) -t $(IMAGENAME):latest .
	docker buildx build $(BUILDARG_VERSION) --load -t $(IMAGENAME):latest .

download: LanguageTool-stable.zip
	-rm -rf LanguageTool-$(VERSION) LanguageTool-$(UNPACKED_VERSION)
	echo ":: unzipping LanguageTool-stable.zip"
	unzip -o LanguageTool-stable.zip 2>&1 1>/dev/null
	@test -f LanguageTool-$(UNPACKED_VERSION)/languagetool-server.jar || \
		{ echo ":: LanguageTool-stable.zip does not contain version $(UNPACKED_VERSION), found: $$(ls -d LanguageTool-*/)"; exit 1; }

LanguageTool-stable.zip:
	curl -fL https://languagetool.org/download/LanguageTool-stable.zip -o LanguageTool-stable.zip

test: test-cleanup.1
test: test-start
test: test-run-test-lang
test: test-run-test-en
test: test-run-test-fr
test: test-cleanup.2

test-start:
	@echo ""
	docker run -d --name languagetool -p 8081:8081 $(IMAGENAME):latest
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
