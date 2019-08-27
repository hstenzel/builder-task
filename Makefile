GIT_URL := $(shell git config --get remote.origin.url)
# GIT_URL_TOKENS is <proto> <host> <account> <repository>
GIT_URL_TOKENS := $(strip $(subst @, ,$(subst .git,,$(subst /, ,$(subst :, ,$(GIT_URL))))))
GIT_ACCOUNT := $(word 3,$(GIT_URL_TOKENS))
GIT_REPOSITORY := $(word 4,$(GIT_URL_TOKENS))
GIT_BRANCH := $(shell git symbolic-ref --short HEAD)
GIT_SHA := $(shell git rev-parse --short HEAD)
GIT_STATUS := $(shell git status --porcelain)

DOCKER ?= docker
PROJECT ?= $(GIT_REPOSITORY)
REPOSITORY ?= $(GIT_ACCOUNT)
FLY_TARGET ?= dev
IMG_UNPACK ?= false

ifeq ($(words $(GIT_STATUS)),0)
  DOCKER_TAG_ARGS := -t $(REPOSITORY)/$(PROJECT):$(GIT_BRANCH) -t $(REPOSITORY)/$(PROJECT):$(GIT_BRANCH).$(GIT_SHA)
else
  DOCKER_TAG_ARGS := -t $(REPOSITORY)/$(PROJECT):$(GIT_BRANCH).SNAPSHOT
endif

.PHONY: all
all: docker

.PHONY: docker
docker:
	$(DOCKER) build $(BUILD_ARGS) $(DOCKER_TAG_ARGS) .

# The test is a self-hosted build
.PHONY: test
test: docker
	docker run --privileged --rm -v $(PWD):/src -e PROJECT=$(PROJECT) $(REPOSITORY)/$(PROJECT) "make release"

release: DOCKER = img
release: docker clean
ifeq ($(IMG_UNPACK),true)
	img unpack -o $(PWD)/release $(REPOSITORY)/$(PROJECT)
endif
	mkdir -p release
	img save -o $(PWD)/release/image.tar $(word 2,$(DOCKER_TAG_ARGS))
	chown -R --reference=. .

.PHONY: clean
clean:
	rm -rf release

.PHONY: fly-execute
fly-execute: clean
	fly -t $(FLY_TARGET) execute -c builder-task.yaml -i src=. -o release=./release -p --include-ignored
