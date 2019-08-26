DOCKER ?= docker
PROJECT ?= $(notdir $(PWD))
REPOSITORY ?= $(USER)
FLY_TARGET ?= dev
IMG_UNPACK ?= false

.PHONY: all
all: docker

.PHONY: docker
docker:
	$(DOCKER) build $(BUILD_ARGS) -t $(REPOSITORY)/$(PROJECT) .

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
	img save -o $(PWD)/release/image.tar $(REPOSITORY)/$(PROJECT)
	chown -R --reference=. .

.PHONY: clean
clean:
	rm -rf release

.PHONY: fly-execute
fly-execute: clean
	fly -t $(FLY_TARGET) execute -c builder-task.yaml -i src=. -o release=./release -p
