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
latest_stable = 1.9
KUBE_VERSION ?= $(latest_stable)
kube_version = $(subst v,,$(KUBE_VERSION))
kube_version_full = $(shell curl -Ss https://storage.googleapis.com/kubernetes-release/release/stable-$(kube_version).txt)
IMAGE = $(REGISTRY)/$(BIN)
in_docker_group=$(filter docker,$(shell groups))                                                                                                                                                                     
is_root=$(filter 0,$(shell id -u))
DOCKER?=$(if $(or $(in_docker_group),$(is_root)),docker,sudo docker)
DIR := ${CURDIR}

.PHONY: all container getbins clean

all: container

e2e.test: getbins
kubectl: getbins
ginkgo: getbins

getbins: | _cache/.getbins.$(kube_version_full).timestamp

_cache/.getbins.$(kube_version_full).timestamp:
	mkdir -p _cache/$(kube_version_full)
	curl -SsL -o _cache/$(kube_version_full)/kubernetes.tar.gz http://gcsweb.k8s.io/gcs/kubernetes-release/release/$(kube_version_full)/kubernetes.tar.gz
	tar -C _cache/$(kube_version_full) -xzf _cache/$(kube_version_full)/kubernetes.tar.gz
	cd _cache/$(kube_version_full) && KUBE_VERSION="${kube_version_full}" \
	                                  KUBERNETES_DOWNLOAD_TESTS=true \
					  KUBERNETES_SKIP_CONFIRM=true ./kubernetes/cluster/get-kube-binaries.sh
	mv _cache/$(kube_version_full)/kubernetes/cluster ./
	mv _cache/$(kube_version_full)/kubernetes/platforms/linux/amd64/e2e.test ./
	mv _cache/$(kube_version_full)/kubernetes/platforms/linux/amd64/ginkgo ./
	mv _cache/$(kube_version_full)/kubernetes/platforms/linux/amd64/kubectl ./
	rm -rf _cache/$(kube_version_full)
	touch $@

container: e2e.test kubectl ginkgo
	$(DOCKER) build -t $(REGISTRY)/$(TARGET):v$(kube_version) \
	                -t $(REGISTRY)/$(TARGET):$(kube_version_full) .
	if [ "$(kube_version)" = "$(latest_stable)" ]; then \
	  $(DOCKER) tag $(REGISTRY)/$(TARGET):v$(kube_version) $(REGISTRY)/$(TARGET):latest; \
	fi

push:
	$(DOCKER) push $(REGISTRY)/$(TARGET):v$(kube_version)
	$(DOCKER) push $(REGISTRY)/$(TARGET):$(kube_version_full)
	if [ "$(kube_version)" = "$(latest_stable)" ]; then \
	  $(DOCKER) push $(REGISTRY)/$(TARGET):latest; \
	fi

clean:
	rm -rf _cache e2e.test kubectl cluster ginkgo
	$(DOCKER) rmi $(REGISTRY)/$(TARGET):latest \
	              $(REGISTRY)/$(TARGET):v$(kube_version) \
		      $(REGISTRY)/$(TARGET):$(kube_version_full) || true
