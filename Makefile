SALT_VERSION := $(shell grep SALT_VERSION Dockerfile.python2 | \
                   cut -d' ' -f2 | cut -d'=' -f2 | sed 's/"//g')
BUILD_TIMESTAMP := $(shell date +%Y%m%d%H%M)
PY_VER=python2
REPO_PREFIX=sre/saltstack

# Use $(error <msg>) to error out

all: build

help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1. make build        - build the saltstack-master image"
	@echo "   2. make quickstart   - start saltstack-master"
	@echo "   3. make stop         - stop saltstack-master"
	@echo "   4. make purge        - stop and remove the container"
	@echo "   5. make logs         - view logs"
	@echo "   6. make push_ecr     - push to an authenticated ECR"

# Use the VERSION file after this has been run
version:
	@echo $(SALT_VERSION) > VERSION

build:
	@docker build --tag=cdalvaro/saltstack-master .

release: build
	@docker build --tag=cdalvaro/saltstack-master:$(shell cat VERSION) .

quickstart:
	@echo "Starting saltstack-master container..."
	@docker run --name='saltstack-master-demo' --detach \
		--publish=4505:4505/tcp --publish=4506:4506/tcp \
		--env "USERMAP_UID=$(shell id -u)" --env "USERMAP_GID=$(shell id -g)" \
		--env SALT_LOG_LEVEL=info \
		--volume $(shell pwd)/roots/:/home/salt/data/srv/ \
		--volume $(shell pwd)/keys/:/home/salt/data/keys/ \
		--volume $(shell pwd)/logs/:/home/salt/data/logs/ \
		cdalvaro/saltstack-master:latest
	@echo "Type 'make logs' for the logs"

stop:
	@echo "Stopping container..."
	@docker stop saltstack-master-demo > /dev/null

purge: stop
	@echo "Removing stopped container..."
	@docker rm saltstack-master-demo > /dev/null

logs:
	@docker logs --follow saltstack-master-demo


# Target-specific variables
push_ecr: ACCTID := $(shell aws sts get-caller-identity --output text --query 'Account')
push_ecr: REGION := $(shell aws configure get region)
push_ecr: REGISTRY := $(ACCTID).dkr.ecr.$(REGION).amazonaws.com/sre/saltstack

push_ecr: version
	@docker build \
	    --tag=$(REGISTRY):$(SALT_VERSION) \
	    --tag=$(REGISTRY):$(SALT_VERSION)-$(BUILD_TIMESTAMP) \
	    -f Dockerfile.$(PY_VER) .
