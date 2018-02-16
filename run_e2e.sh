#!/bin/bash
##########################################################################
# Copyright 2017 Heptio Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# tar up the results for transmission back
finish () {
    # e2e.test responds to INT but not to TERM so we raise TERM to INT.
    # TODO(chuckha) pkill doesn't seem to have the same effect, find out why
    PID=$(pgrep e2e.test)
    kill -INT ${PID}
    wait ${PID}
    cd "${RESULTS_DIR}"
    tar -czf e2e.tar.gz ./*
    # mark the done file as a termination notice.
    echo -n "${RESULTS_DIR}/e2e.tar.gz" > "${RESULTS_DIR}/done"
}

# Write out the done file no matter what happens.
trap finish EXIT

echo "/usr/local/bin/e2e.test --disable-log-dump --repo-root=/kubernetes --ginkgo.skip=\"${E2E_SKIP}\" --ginkgo.focus=\"${E2E_FOCUS}\" --provider=\"${E2E_PROVIDER}\" --report-dir=\"${RESULTS_DIR}\" --kubeconfig=\"${KUBECONFIG}\" --ginkgo.noColor=true"
/usr/local/bin/e2e.test --disable-log-dump --repo-root=/kubernetes --ginkgo.skip="${E2E_SKIP}" --ginkgo.focus="${E2E_FOCUS}" --provider="${E2E_PROVIDER}" --report-dir="${RESULTS_DIR}" --kubeconfig="${KUBECONFIG}" --ginkgo.noColor=true | tee ${RESULTS_DIR}/e2e.log
