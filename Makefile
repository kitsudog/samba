SNAME ?= samba
RNAME ?= elswork/$(SNAME)
VER ?= `cat VERSION`
BASE ?= latest
BASENAME ?= alpine:$(BASE)
ARCH2 ?= armv7l
ARCH3 ?= aarch64
GOARCH := $(shell uname -m)
ifeq ($(GOARCH),x86_64)
	GOARCH := amd64
endif

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# DOCKER TASKS

debug: ## Debug the container
	docker build -t $(RNAME):$(GOARCH) \
	--build-arg BASEIMAGE=$(BASENAME) \
	--build-arg VERSION=$(GOARCH)_$(VER) .
build: ## Build the container
	docker build --no-cache -t $(RNAME):$(GOARCH) \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	--build-arg BASEIMAGE=$(BASENAME) \
	--build-arg VERSION=$(GOARCH)_$(VER) \
	. > builds/$(GOARCH)_$(VER)_`date +"%Y%m%d_%H%M%S"`.txt
bootstrap: ## Start multicompiler
	docker buildx inspect --bootstrap
debugx: ## Buildx in Debug mode
	docker buildx build \
	-t $(RNAME):debug --pull --load \
	--build-arg BASEIMAGE=$(BASENAME) \
	--build-arg VERSION=$(VER) .
buildx: ## Buildx the container
	mkdir -p builds
	docker buildx build --no-cache \
	--platform linux/amd64,linux/arm64,linux/ppc64le,linux/s390x,linux/386,linux/arm/v7,linux/arm/v6 \
	-t $(RNAME):latest -t $(RNAME):$(VER) --pull --push \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	--build-arg BASEIMAGE=$(BASENAME) \
	--build-arg VERSION=$(VER) .
tag: ## Tag the container
	docker tag $(RNAME):$(GOARCH) $(RNAME):$(GOARCH)_$(VER)
push: ## Push the container
	docker push $(RNAME):$(GOARCH)_$(VER)
	docker push $(RNAME):$(GOARCH)	
deploy: build tag push
manifest: ## Create an push manifest
	docker manifest create $(RNAME):$(VER) \
	$(RNAME):$(GOARCH)_$(VER) \
	$(RNAME):$(ARCH2)_$(VER) \
	$(RNAME):$(ARCH3)_$(VER)
	docker manifest push --purge $(RNAME):$(VER)
	docker manifest create $(RNAME):latest $(RNAME):$(GOARCH) \
	$(RNAME):$(ARCH2) \
	$(RNAME):$(ARCH3)
	docker manifest push --purge $(RNAME):latest
pull: ## Pull latest image
	docker pull elswork/samba
start: ## Start samba
	docker run -d -p 139:139 -p 445:445 -e TZ=Europe/Madrid \
	-v /home/pirate/docker/makefile:/share/folder elswork/samba \
	-u "1000:1000:pirate:pirate:put-any-password-here" \
	-s "SmbShare:/share/folder:rw:pirate"
