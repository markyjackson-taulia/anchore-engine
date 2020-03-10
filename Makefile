# Environment Variables - export to required make commands to utilize
ANCHORE_CLI_VERSION ?= $(shell echo $${CIRCLE_TAG})
DEV_IMAGE_REPO ?= anchore/anchore-engine-dev
# Use $CIRCLE_BRANCH if it's set, otherwise use current HEAD branch
GIT_BRANCH := $(shell echo $${CIRCLE_BRANCH:=$$(git rev-parse --abbrev-ref HEAD)})
# Use $CIRCLE_PROJECT_REPONAME if it's set, otherwise the git project top level dir name
GIT_REPO := $(shell echo $${CIRCLE_PROJECT_REPONAME:=$$(basename `git rev-parse --show-toplevel`)})
# Use $CIRCLE_SHA if it's set, otherwise use SHA from HEAD
COMMIT_SHA := $(shell echo $${CIRCLE_SHA:=$$(git rev-parse HEAD)})
# Use $CIRCLE_TAG if it's set
GIT_TAG := $(shell echo $${CIRCLE_TAG})

# Testing environment configuration
TEST_IMAGE_NAME := $(GIT_REPO):dev
TEST_DEPS := tox docker-compose

# Environment variables set by CircleCI - keep these vars empty to prevent accidental pushes to DockerHub
CI ?=
DOCKER_PASS ?=
DOCKER_USER ?=
LATEST_RELEASE_BRANCH ?=
PROD_IMAGE_REPO ?=
RELEASE_BRANCHES ?=

# export global variables to make them available to all make commands
export VERBOSE ?= false
export VENV := venv
export PYTHON := $(VENV)/bin/python3

# RUN_SCRIPT is a wrapper script used to invoke tasks found in scripts/ci/make/tasks
# These scripts are where all individual tasks for the pipeline belong
RUN_SCRIPT := scripts/ci/make/run_task_script

# Make environment configuration
ENV := /usr/bin/env
.DEFAULT_GOAL := help # Running `Make` will run the help target
.NOTPARALLEL: # wait for targets to finish

# Define available make commands -- use ## on target names to create 'help' text

.PHONY: ci ## run full ci pipeline locally
ci: VERBOSE := true
ci: build test push

.PHONY: build
build: Dockerfile ## build dev image
	@export \
		ANCHORE_CLI_VERSION=$(ANCHORE_CLI_VERSION) \
		COMMIT_SHA=$(COMMIT_SHA) \
		GIT_REPO=$(GIT_REPO) \
		GIT_TAG=$(GIT_TAG) \
		TEST_IMAGE_NAME=$(TEST_IMAGE_NAME) && \
	$(RUN_SCRIPT) build

.PHONY: push push-dev
push: push-dev ## push dev image to dockerhub
push-dev: 
	@export \
		CI=$(CI) \
		COMMIT_SHA=$(COMMIT_SHA) \
		DEV_IMAGE_REPO=$(DEV_IMAGE_REPO) \
		DOCKER_PASS=$(DOCKER_PASS) \
		DOCKER_USER=$(DOCKER_USER) \
		GIT_BRANCH=$(GIT_BRANCH) \
		RELEASE_BRANCHES=$(RELEASE_BRANCHES) \
		TEST_IMAGE_NAME=$(TEST_IMAGE_NAME) && \
	$(RUN_SCRIPT) common/push_dev_image

.PHONY: push-rc
push-rc: 
	@export \
		CI=$(CI) \
		COMMIT_SHA=$(COMMIT_SHA) \
		DEV_IMAGE_REPO=$(DEV_IMAGE_REPO) \
		DOCKER_PASS=$(DOCKER_PASS) \
		DOCKER_USER=$(DOCKER_USER) \
		GIT_TAG=$(GIT_TAG) && \
	$(RUN_SCRIPT) common/push_rc_image

.PHONY: push-rebuild
push-rebuild: 
	@export \
		CI=$(CI) \
		COMMIT_SHA=$(COMMIT_SHA) \
		DEV_IMAGE_REPO=$(DEV_IMAGE_REPO) \
		DOCKER_PASS=$(DOCKER_PASS) \
		DOCKER_USER=$(DOCKER_USER) \
		GIT_TAG=$(GIT_TAG) \
		PROD_IMAGE_REPO=$(PROD_IMAGE_REPO) && \
	$(RUN_SCRIPT) common/push_prod_image_rebuild

.PHONY: push-release
push-release: 
	@export \
		CI=$(CI) \
		DEV_IMAGE_REPO=$(DEV_IMAGE_REPO) \
		DOCKER_PASS=$(DOCKER_PASS) \
		DOCKER_USER=$(DOCKER_USER) \
		GIT_BRANCH=$(GIT_BRANCH) \
		GIT_TAG=$(GIT_TAG) \
		LATEST_RELEASE_BRANCH=$(LATEST_RELEASE_BRANCH) \
		PROD_IMAGE_REPO=$(PROD_IMAGE_REPO) && \
	$(RUN_SCRIPT) common/push_prod_image_release

.PHONY: venv
venv: $(VENV)/bin/activate ## setup virtual environment
$(VENV)/bin/activate:
	@$(RUN_SCRIPT) common/setup_venv

.PHONY: install
install: venv setup.py requirements.txt ## install project to virtual environment
	@$(RUN_SCRIPT) common/install

.PHONY: install-dev
install-dev: venv setup.py requirements.txt ## install project to virtual environment in editable mode
	@$(RUN_SCRIPT) common/install_dev

.PHONY: compose-up
compose-up: venv scripts/ci/docker-compose-ci.yaml ## run docker compose with dev image
	@export \
		TEST_IMAGE_NAME=$(TEST_IMAGE_NAME) && \
	$(RUN_SCRIPT) common/docker_compose_up

.PHONY: compose-down
compose-down: venv scripts/ci/docker-compose-ci.yaml ## stop docker compose
	@export \
		TEST_IMAGE_NAME=$(TEST_IMAGE_NAME) && \
	$(RUN_SCRIPT) common/docker_compose_down

.PHONY: cluster-up
cluster-up: venv test/e2e/kind-config.yaml ## run kind testing k8s cluster
	@$(RUN_SCRIPT) common/install_cluster_deps
	@$(RUN_SCRIPT) common/kind_cluster_up

.PHONY: cluster-down
cluster-down: venv ## delete kind testing k8s cluster
	@$(RUN_SCRIPT) common/install_cluster_deps
	@$(RUN_SCRIPT) common/kind_cluster_down

.PHONY: lint
lint: venv ## lint code using pylint
	@$(RUN_SCRIPT) lint

.PHONY: test
test: test-unit test-integration test-functional test-e2e ## run all test make recipes -- test-unit, test-integration, test-functional, test-e2e

.PHONY: test-deps
test-deps: $(VENV)/.deps_installed
$(VENV)/.deps_installed: venv
	@export \
		TEST_DEPS="$(TEST_DEPS)" && \
	$(RUN_SCRIPT) common/install_testing_deps
	@touch $@

.PHONY: test-unit
test-unit: test-deps
	@$(RUN_SCRIPT) unit_tests

.PHONY: test-integration
test-integration: test-deps
	@export \
		CI=$(CI) && \
	$(RUN_SCRIPT) integration_tests

.PHONY: test-functional
test-functional: compose-up
	@$(MAKE) run-test-functional
	@$(MAKE) compose-down

.PHONY: run-test-functional
run-test-functional: test-deps
	@$(RUN_SCRIPT) functional_tests

.PHONY: test-e2e
test-e2e: setup-test-e2e
	@$(MAKE) run-test-e2e
	@$(MAKE) cluster-down

.PHONY: setup-test-e2e
setup-test-e2e: cluster-up
	@export \
		COMMIT_SHA=$(COMMIT_SHA) \
		DEV_IMAGE_REPO=$(DEV_IMAGE_REPO) \
		DOCKER_PASS=$(DOCKER_PASS) \
		DOCKER_USER=$(DOCKER_USER) \
		GIT_TAG=$(GIT_TAG) \
		TEST_IMAGE_NAME=$(TEST_IMAGE_NAME) && \
	$(RUN_SCRIPT) setup_e2e_tests

.PHONY: run-test-e2e
run-test-e2e: test-deps
	@$(RUN_SCRIPT) run_e2e_tests

.PHONY: clean
clean: ## clean up project directory & delete dev image
	@export \
		TEST_IMAGE_NAME=$(TEST_IMAGE_NAME) && \
	$(RUN_SCRIPT) common/clean_project_dir

.PHONY: printvars
printvars: ## print configured make environment vars
	@$(foreach V,$(sort $(.VARIABLES)),$(if $(filter-out environment% default automatic,$(origin $V)),$(warning $V=$($V) ($(value $V)))))

.PHONY: help
help:
	@$(RUN_SCRIPT) help
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[0;36m%-30s\033[0m %s\n", $$1, $$2}'
