# Copyright 2017 Heptio Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Note the only reason we are creating this is because upstream
# does not yet publish a released e2e container
# https://github.com/kubernetes/kubernetes/issues/47920

TARGET = kube-conformance
GOTARGET = github.com/heptio/$(TARGET)
REGISTRY ?= gcr.io/heptio-images
latest_stable = 1.15
KUBE_VERSION ?= $(latest_stable)
kube_version = $(subst v,,$(KUBE_VERSION))
kube_version_full = $(shell curl -Ss https://storage.googleapis.com/kubernetes-release/release/stable-$(kube_version).txt)
IMAGE = $(REGISTRY)/$(BIN)
in_docker_group=$(filter docker,$(shell groups))
is_root=$(filter 0,$(shell id -u))
DOCKER?=$(if $(or $(in_docker_group),$(is_root)),docker,sudo docker)
DIR := ${CURDIR}

ARCH    ?= amd64
LINUX_ARCHS = amd64 arm64
PLATFORMS = linux/amd64,linux/arm64

IMAGEARCH ?=
QEMUARCH  ?=

MANIFEST_TOOL_VERSION := v1.0.0-rc

ifneq ($(ARCH),amd64)
IMAGE_TAG = $(IMAGE_REPO)-$(ARCH):$(IMAGE_TAG_NAME)
endif

ifeq ($(ARCH),amd64)
IMAGEARCH =
QEMUARCH  = x86_64
else ifeq ($(ARCH),arm)
IMAGEARCH = arm32v7/
QEMUARCH  = arm
else ifeq ($(ARCH),arm64)
IMAGEARCH = arm64v8/
QEMUARCH  = aarch64
else ifeq ($(ARCH),ppc64le)
IMAGEARCH = ppc64le/
QEMUARCH  = ppc64le
else ifeq ($(ARCH),s390x)
IMAGEARCH = s390x/
QEMUARCH  = s390x
else
$(error unknown arch "$(ARCH)")
endif



.PHONY: all container getbins clean

all: container

e2e.test: getbins
kubectl: getbins
ginkgo: getbins

getbins: | _cache/.getbins.$(kube_version_full).timestamp

_cache/.getbins.$(kube_version_full).timestamp:
	mkdir -p _cache/$(kube_version_full)

	curl -SsL http://gcsweb.k8s.io/gcs/kubernetes-release/release/$(kube_version_full)/kubernetes.tar.gz | tar -C _cache/$(kube_version_full) -xz
	cd _cache/$(kube_version_full) && KUBE_VERSION="${kube_version_full}" \
	                                  KUBERNETES_DOWNLOAD_TESTS=true \
					  KUBERNETES_CLIENT_ARCH=$(ARCH) \
					  KUBERNETES_SERVER_ARCH=$(ARCH) \
					  KUBERNETES_SKIP_CONFIRM=true ./kubernetes/cluster/get-kube-binaries.sh
	mv _cache/$(kube_version_full)/kubernetes/cluster ./
	mv _cache/$(kube_version_full)/kubernetes/platforms/linux/$(ARCH)/e2e.test ./
	mv _cache/$(kube_version_full)/kubernetes/platforms/linux/$(ARCH)/ginkgo ./
	mv _cache/$(kube_version_full)/kubernetes/platforms/linux/$(ARCH)/kubectl ./
	touch $@

pre-cross:
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

build-container: e2e.test kubectl ginkgo
	$(DOCKER) build --build-arg IMAGEARCH=$(IMAGEARCH) \
		--build-arg QEMUARCH=$(QEMUARCH) \
		-t $(REGISTRY)/$(TARGET):v$(kube_version) \
		-t $(REGISTRY)/$(TARGET):$(kube_version_full) .
	if [ "$(kube_version)" = "$(latest_stable)" ]; then \
	  $(DOCKER) tag $(REGISTRY)/$(TARGET):v$(kube_version) $(REGISTRY)/$(TARGET):latest; \
	fi

container: pre-cross
	for arch in $(LINUX_ARCHS); do \
		$(MAKE) build-container ARCH=$$arch TARGET="kube-conformance-$$arch" \
		rm -rf  _cache; \
		rm -rf ./cluster; \
		rm -rf e2e.test ginkgo kubectl; \
	done

push-image:
	$(DOCKER) push $(REGISTRY)/$(TARGET):v$(kube_version)
	$(DOCKER) push $(REGISTRY)/$(TARGET):$(kube_version_full)
	if [ "$(kube_version)" = "$(latest_stable)" ]; then \
	  $(DOCKER) push $(REGISTRY)/$(TARGET):latest; \
	fi

push_manifest:
	./manifest-tool -username oauth2accesstoken --password "`gcloud auth print-access-token`" push from-args --platforms $(PLATFORMS) --template $(REGISTRY)/$(TARGET)-ARCH:$(VERSION) --target  $(REGISTRY)/$(TARGET):$(VERSION)

pre-push:
	curl -sSL https://github.com/estesp/manifest-tool/releases/download/$(MANIFEST_TOOL_VERSION)/manifest-tool-linux-amd64 > manifest-tool
	chmod +x manifest-tool

#push: pre-push container
push: pre-push
	for arch in $(LINUX_ARCHS); do \
		$(MAKE) push-image TARGET="kube-conformance-$$arch" \
	done

	$(MAKE) push_manifest VERSION=latest
	$(MAKE) push_manifest

clean-image:
	rm -rf _cache e2e.test kubectl cluster ginkgo
	$(DOCKER) rmi $(REGISTRY)/$(TARGET):latest \
	              $(REGISTRY)/$(TARGET):v$(kube_version) \
		      $(REGISTRY)/$(TARGET):$(kube_version_full) || true

clean:
	rm -f manifest-tool*
	for arch in $(LINUX_ARCHS); do \
		$(MAKE) clean-image TARGET="kube-conformance-$$arch"; \
	done
