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
shutdown () {
    echo "sending TERM to ${PID}"
    kill -s INT "${PID}"
    wait "${PID}"
}

# We get the TERM from kubernetes and handle it gracefully
trap shutdown TERM

E2E_PARALLEL=${E2E_PARALLEL:-n}
GINKGO_PARALLEL_ARGS=()
case ${E2E_PARALLEL} in
    'y'|'Y')           GINKGO_PARALLEL_ARGS+=("--ginkgo.parallel.total=\"25\"") ;;
    [1-9]|[1-9][0-9]*) GINKGO_PARALLEL_ARGS+=("--ginkgo.parallel.total=\"${E2E_PARALLEL}\"") ;;
esac

echo "/usr/local/bin/e2e.test --disable-log-dump --repo-root=/kubernetes --ginkgo.skip=\"${E2E_SKIP}\" --ginkgo.focus=\"${E2E_FOCUS}\" --provider=\"${E2E_PROVIDER}\" --report-dir=\"${RESULTS_DIR}\" --kubeconfig=\"${KUBECONFIG}\" --ginkgo.noColor=true ${GINKGO_PARALLEL_ARGS[@]}"
/usr/local/bin/e2e.test --disable-log-dump --repo-root=/kubernetes --ginkgo.skip="${E2E_SKIP}" --ginkgo.focus="${E2E_FOCUS}" --provider="${E2E_PROVIDER}" --report-dir="${RESULTS_DIR}" --kubeconfig="${KUBECONFIG}" --ginkgo.noColor=true ${GINKGO_PARALLEL_ARGS[@]} | tee ${RESULTS_DIR}/e2e.log &
# $! is the pid of tee, not e2e.test
PID="$(jobs -p)"
wait "${PID}"
cd "${RESULTS_DIR}" || exit
tar -czf e2e.tar.gz ./*
# mark the done file as a termination notice.
echo -n "${RESULTS_DIR}/e2e.tar.gz" > "${RESULTS_DIR}/done"
