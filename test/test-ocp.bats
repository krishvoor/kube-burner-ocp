#!/usr/bin/env bats
# vi: ft=bash
# shellcheck disable=SC2086,SC2164

load helpers.bash

setup_file() {
  cd ocp
  export BATS_TEST_TIMEOUT=600
  export ES_SERVER="https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com"
  export ES_INDEX="kube-burner-ocp"
  trap print_events ERR
  setup-prometheus
}

setup() {
  export UUID; UUID=$(uuidgen)
  export COMMON_FLAGS="--es-server=${ES_SERVER} --es-index=${ES_INDEX} --alerting=true --uuid=${UUID} --qps=5 --burst=5"
}

teardown() {
  oc delete ns -l kube-burner-uuid="${UUID}" --ignore-not-found
  # web-burner workload specific
  oc label node -l node-role.kubernetes.io/worker-spk= node-role.kubernetes.io/worker-spk-
  oc delete AdminPolicyBasedExternalRoute --all
}

teardown_file() {
  $OCI_BIN rm -f prometheus
}


@test "web-burner-node-density" {
  LB_WORKER=$(oc get node | grep worker | head -n 1 | cut -f 1 -d' ')
  run_cmd oc label node $LB_WORKER node-role.kubernetes.io/worker-spk="" --overwrite
  run_cmd kube-burner-ocp web-burner-init --gc=false --sriov=true --bridge=br-ex --bfd=true --es-server="" --es-index="" --alerting=true --uuid=${UUID} --qps=5 --burst=5
  run_cmd kube-burner-ocp web-burner-node-density --gc=false --probe=false --es-server="" --es-index="" --alerting=true --uuid=${UUID} --qps=5 --burst=5
  check_running_pods kube-burner-job=init-served-job 1
  check_running_pods kube-burner-job=serving-job 4
  check_running_pods kube-burner-job=normal-job-1 60
  run_cmd oc delete project served-ns-0 serving-ns-0
}

@test "web-burner-cluster-density" {
  LB_WORKER=$(oc get node | grep worker | head -n 1 | cut -f 1 -d' ')
  run_cmd oc label node $LB_WORKER node-role.kubernetes.io/worker-spk="" --overwrite
  run_cmd kube-burner-ocp web-burner-init --gc=false --sriov=true --bridge=br-ex --bfd=true --es-server="" --es-index="" --alerting=true --uuid=${UUID} --qps=5 --burst=5
  run_cmd kube-burner-ocp web-burner-cluster-density --gc=false --probe=false --es-server="" --es-index="" --alerting=true --uuid=${UUID} --qps=5 --burst=5
  check_running_pods kube-burner-job=init-served-job 1
  check_running_pods kube-burner-job=serving-job 4
  check_running_pods kube-burner-job=cluster-density 35
  check_running_pods kube-burner-job=app-job-1 3
}
