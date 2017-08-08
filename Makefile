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
KVER = v1.7.3
IMAGE = $(REGISTRY)/$(BIN)
DOCKER ?= docker
DIR := ${CURDIR}

.PHONY: all container getbins clean

all: container

e2e.test: getbins
kubectl: getbins

getbins: | _cache/.getbins.$(KVER).timestamp

_cache/.getbins.$(KVER).timestamp:
	mkdir -p _cache/$(KVER)
	curl -L -o _cache/$(KVER)/kubernetes.tar.gz http://gcsweb.k8s.io/gcs/kubernetes-release/release/$(KVER)/kubernetes.tar.gz
	tar -C _cache/$(KVER) -xzf _cache/$(KVER)/kubernetes.tar.gz
	cd _cache/$(KVER) && KUBERNETES_DOWNLOAD_TESTS=true KUBERNETES_SKIP_CONFIRM=true ./kubernetes/cluster/get-kube-binaries.sh
	mv _cache/$(KVER)/kubernetes/platforms/linux/amd64/e2e.test ./
	mv _cache/$(KVER)/kubernetes/platforms/linux/amd64/kubectl ./
	rm -rf _cache/$(KVER)
	touch $@

container: e2e.test kubectl
	$(DOCKER) build -t $(REGISTRY)/$(TARGET):latest -t $(REGISTRY)/$(TARGET):$(KVER) .

push:
	$(DOCKER) push $(REGISTRY)/$(TARGET):latest
	$(DOCKER) push $(REGISTRY)/$(TARGET):$(KVER)

clean:
	rm -rf _cache e2e.test kubectl
	$(DOCKER) rmi $(REGISTRY)/$(TARGET):latest $(REGISTRY)/$(TARGET):$(KVER) || true
