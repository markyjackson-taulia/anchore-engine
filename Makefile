# This Makefile requires make v3.8.2 or newer to function properly due to the .ONESHELL directive. (for macos - `brew install gmake` then add `alias make=gmake` to your .bash_profile)
# Project Specific configuration
CI ?= false
# Use $CIRCLE_SHA or use SHA from HEAD
COMMIT ?= $(shell echo $${CIRCLE_SHA:=$$(git rev-parse HEAD)})
# Use $CIRCLE_BRANCH or use current HEAD branch
GIT_REPO ?= $(shell echo $${CIRCLE_PROJECT_REPONAME:=$$(basename `git rev-parse --show-toplevel`)})
GIT_BRANCH ?= $(shell echo $${CIRCLE_BRANCH:=$$(git rev-parse --abbrev-ref HEAD)})
CLI_COMMIT ?= $(shell (git ls-remote git@github.com:anchore/anchore-cli "refs/heads/$(GIT_BRANCH)" | awk '{ print $$1 }'))
IMAGE_TAG = $(COMMIT)
IMAGE_REPOSITORY = anchore/anchore-engine-dev
IMAGE_NAME = $(IMAGE_REPOSITORY):$(IMAGE_TAG)
RELEASE_BRANCHES = '(0.2|0.3|0.4|0.5|0.6)'
PYTHON_VERSION = 3.6.6

# Make environment configuration
ENV = /usr/bin/env
VENV_NAME = venv
VENV_ACTIVATE = . $(VENV_NAME)/bin/activate
PYTHON = $(VENV_NAME)/bin/python3
SHELL = /bin/bash
.SHELLFLAGS = -o pipefail -ec # run commands in a -o pipefail -ec flag
.DEFAULT_GOAL := help # Running `Make` will run the help target
.ONESHELL: # Run every line in recipes in same shell
.NOTPARALLEL: # wait for targets to finish
.EXPORT_ALL_VARIABLES: # send all vars to shell

.PHONY: install ## install anchore-engine to venv
install: venv setup.py requirements.txt
	${PYTHON} -m pip install --editable .

.PHONY: build
build: Dockerfile ## build image
	docker build --build-arg ANCHORE_COMMIT=$(COMMIT) --build-arg CLI_COMMIT=$(CLI_COMMIT) -t anchore-engine:test -f ./Dockerfile .
	docker tag anchore-engine:test $(IMAGE_NAME)

.PHONY: compose-up
compose-up: $(VENV_NAME)/docker-compose.yaml ## run container with docker-compose.yaml file
$(VENV_NAME)/docker-compose.yaml: docker-compose.yaml deps
	$(VENV_ACTIVATE)
	mkdir -p $(VENV_NAME)/compose/$(COMMIT)
	cp docker-compose.yaml $(VENV_NAME)/compose/$(COMMIT)/docker-compose.yaml
	sed -i "s|anchore/anchore-engine:.*$$|$(IMAGE_NAME)|g" $(VENV_NAME)/compose/$(COMMIT)/docker-compose.yaml
	docker-compose -f $(VENV_NAME)/compose/$(COMMIT)/docker-compose.yaml up -d
	printf '\n%s\n' "To stop anchore-engine use: make compose-down"

.PHONY: compose-down
compose-down:
	$(VENV_ACTIVATE)
	docker-compose -f $(VENV_NAME)/compose/$(COMMIT)/docker-compose.yaml down
	rm -rf $(VENV_NAME)/compose/$(COMMIT)

.PHONY: push
push: ## push image to dockerhub
	if [[ $(CI) == true ]]; then
		docker load -i "/home/circleci/workspace/caches/$(GIT_REPO)-$(COMMIT).tar"
		if [[ $(GIT_BRANCH) == 'master' ]]; then
			echo "tagging & pushing image -- docker.io/anchore/anchore-engine:dev"
			docker tag $(IMAGE_NAME) docker.io/anchore/anchore-engine:dev
			docker push docker.io/anchore/anchore-engine:dev
		elif [[ $(GIT_BRANCH) =~ $(RELEASE_BRANCHES) ]]; then
			echo "tagging & pushing image -- docker.io/anchore/anchore-engine:$(GIT_BRANCH)-dev"
			docker tag $(IMAGE_NAME) docker.io/anchore/anchore-engine:$(GIT_BRANCH)-dev
			docker push docker.io/anchore/anchore-engine:$(GIT_BRANCH)-dev
		fi
	fi
	echo "Pushing $(IMAGE_NAME) && $(IMAGE_REPOSITORY):latest"
	docker tag $(IMAGE_NAME) $(IMAGE_REPOSITORY):latest
	docker push $(IMAGE_REPOSITORY):latest
	docker push $(IMAGE_NAME)

.PHONY: lint
lint: venv ## lint code with pylint
	$(VENV_ACTIVATE)
	hash pylint || pip install --upgrade pylint
	pylint anchore_engine
	pylint anchore_manager

.PHONY: deps
deps: venv ## install testing dependencies
	@$(VENV_ACTIVATE)
	mkdir -p .tox
	hash tox || pip install tox
	hash docker-compose || pip install docker-compose

.PHONY: test
test-all: test-unit test-integration test-functional test-compose ## run all tests - unit, integration, functional, e2e

.PHONY: test-unit
test-unit: deps ## run unit tests with tox
	$(VENV_ACTIVATE)
	tox test/unit | tee .tox/tox.log

.PHONY: test-integration
test-integration: deps ## run integration tests with tox
	$(VENV_ACTIVATE)
	if [[ $(CI) == true ]]; then
		tox test/integration | tee .tox/tox.log
	else
		./scripts/tests/test_with_deps.sh test/integration/
	fi

.PHONY: test-functional
test-functional: deps ## run functional tests with tox
	$(VENV_ACTIVATE)
	tox test/functional | tee .tox/tox.log

.PHONY: test-compose
test-compose: compose-up ## run compose tests with docker-compose
	$(VENV_ACTIVATE)
	hash anchore-cli || pip install anchorecli
	anchore-cli --u admin --p foobar --url http://localhost:8228/v1 system wait --feedsready ''
	docker-compose logs engine-api
	anchore-cli --u admin --p foobar --url http://localhost:8228/v1 system status
	python scripts/tests/aetest.py docker.io/alpine:latest
	python scripts/tests/aefailtest.py docker.io/alpine:latest
	make compose-down

.PHONY: clean-all
clean-all: clean clean-tests clean-pyc clean-container ## clean all build/test artifacts

.PHONY: clean
clean: ## delete all build directories & virtualenv
	rm -rf venv \
		*.egg-info \
		dist \
		build 

.PHONY: clean-tests
clean-tests: ## delete test dirs
	rm -rf .tox
	rm -f tox.log
	rm -rf .pytest_cache

.PHONY: clean-pyc
clean-pyc: ## deletes all .pyc files
	find . -name '*.pyc' -exec rm -f {} \;

.PHONY: clean-container
clean-container: ## delete built image
	docker rmi $(IMAGE_NAME)

.PHONY: venv
venv: $(VENV_NAME)/bin/activate ## setup virtual environment
$(VENV_NAME)/bin/activate:
	if [[ $(CI) == true ]]; then
		hash pip || pip install pip
		hash virtualenv || pip install virtualenv
	else
		hash pip || (echo 'ensure python-pip is installed before attempting to setup virtualenv' && exit 1)
		hash virtualenv || (echo 'ensure virtualenv is installed before attempting to setup virtualenv - `pip install virtualenv`' && exit 1)
	fi
	test -f $(VENV_NAME)/bin/python3 || virtualenv -p python3 $(VENV_NAME)
	touch $@

.PHONY: help
help: ## show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
