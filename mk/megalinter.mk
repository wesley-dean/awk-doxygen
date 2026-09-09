# Reusable MegaLinter execution settings.
#
# Project-specific lint policy belongs in .mega-linter.yml.  This fragment owns
# the runtime mechanism and optional infrastructure overrides used to execute
# MegaLinter efficiently across projects.

LINT_REGISTRY ?= ghcr.io
LINT_IMAGE ?= oxsecurity/megalinter
LINT_TAG ?= latest

LINTER ?= $(LINT_REGISTRY)/$(LINT_IMAGE):$(LINT_TAG)

LINT_GRYPE_DB_URL ?= https://grype.anchore.io/databases
LINT_GRYPE_CACHE_VOLUME ?=
LINT_GRYPE_CACHE_DIR ?= /var/cache/grype/db

LINT_GRYPE_CACHE_ARGS :=
ifneq ($(strip $(LINT_GRYPE_CACHE_VOLUME)),)
LINT_GRYPE_CACHE_ARGS := \
	-v "$(LINT_GRYPE_CACHE_VOLUME):$(LINT_GRYPE_CACHE_DIR):rw" \
	-e GRYPE_DB_CACHE_DIR="$(LINT_GRYPE_CACHE_DIR)"
endif

LINT_TRIVY_CACHE_VOLUME ?=
LINT_TRIVY_CACHE_DIR ?= /var/cache/trivy

LINT_TRIVY_CACHE_ARGS :=
ifneq ($(strip $(LINT_TRIVY_CACHE_VOLUME)),)
LINT_TRIVY_CACHE_ARGS := \
	-v "$(LINT_TRIVY_CACHE_VOLUME):$(LINT_TRIVY_CACHE_DIR):rw" \
	-e TRIVY_CACHE_DIR="$(LINT_TRIVY_CACHE_DIR)"
endif

LINT_CHECKOV_EXTERNAL_MODULES_VOLUME ?=
LINT_CHECKOV_EXTERNAL_MODULES_DIR ?= /var/cache/checkov/external_modules

LINT_CHECKOV_EXTERNAL_MODULES_ARGS :=
ifneq ($(strip $(LINT_CHECKOV_EXTERNAL_MODULES_VOLUME)),)
LINT_CHECKOV_EXTERNAL_MODULES_ARGS := \
	-v "$(LINT_CHECKOV_EXTERNAL_MODULES_VOLUME):$(LINT_CHECKOV_EXTERNAL_MODULES_DIR):rw" \
	-e EXTERNAL_MODULES_DIR="$(LINT_CHECKOV_EXTERNAL_MODULES_DIR)"
endif

LINT_KINGFISHER_CACHE_VOLUME ?=
LINT_KINGFISHER_CACHE_DIR ?= /var/cache/kingfisher/rule-cache

LINT_KINGFISHER_CACHE_ARGS :=
ifneq ($(strip $(LINT_KINGFISHER_CACHE_VOLUME)),)
LINT_KINGFISHER_CACHE_ARGS := \
	-v "$(LINT_KINGFISHER_CACHE_VOLUME):$(LINT_KINGFISHER_CACHE_DIR):rw" \
	-e KF_RULE_CACHE_DIR="$(LINT_KINGFISHER_CACHE_DIR)"
endif

LINT_SYFT_CACHE_VOLUME ?=
LINT_SYFT_CACHE_DIR ?= /var/cache/syft

LINT_SYFT_CACHE_ARGS :=
ifneq ($(strip $(LINT_SYFT_CACHE_VOLUME)),)
LINT_SYFT_CACHE_ARGS := \
	-v "$(LINT_SYFT_CACHE_VOLUME):$(LINT_SYFT_CACHE_DIR):rw" \
	-e SYFT_CACHE_DIR="$(LINT_SYFT_CACHE_DIR)"
endif

# OSV-Scanner uses its local database cache only when repository policy enables
# its local/offline vulnerability database mode.  Leaving the volume unset keeps
# the scanner's normal online behavior unchanged.
LINT_OSV_CACHE_VOLUME ?=
LINT_OSV_CACHE_DIR ?= /var/cache/osv-scanner

LINT_OSV_CACHE_ARGS :=
ifneq ($(strip $(LINT_OSV_CACHE_VOLUME)),)
LINT_OSV_CACHE_ARGS := \
	-v "$(LINT_OSV_CACHE_VOLUME):$(LINT_OSV_CACHE_DIR):rw" \
	-e OSV_SCANNER_LOCAL_DB_CACHE_DIRECTORY="$(LINT_OSV_CACHE_DIR)"
endif

.PHONY: lint

lint:
	docker run --rm \
		$(LINT_GRYPE_CACHE_ARGS) \
		$(LINT_TRIVY_CACHE_ARGS) \
		$(LINT_CHECKOV_EXTERNAL_MODULES_ARGS) \
		$(LINT_KINGFISHER_CACHE_ARGS) \
		$(LINT_SYFT_CACHE_ARGS) \
		$(LINT_OSV_CACHE_ARGS) \
		-v "$$(pwd):/tmp/lint:rw" \
		-e GRYPE_DB_UPDATE_URL="$(LINT_GRYPE_DB_URL)" \
		$(LINTER)
