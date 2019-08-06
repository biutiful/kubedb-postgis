#!/usr/bin/env bash

set -euxo pipefail

ROOT="$( dirname "${BASH_SOURCE[0]}" )"
DOCKER_REGISTRY=${DOCKER_REGISTRY:-biutiful}
IMG=${IMG:-kubedb-postgis}
POSTGRES_VERSIONS=${POSTGRES_VERSIONS:-}
POSTGIS_VERSION=${POSTGIS_VERSION:-2.5.2}

usage() {
  echo "build-all.sh - build kubedb-postgis docker image and create postgresversion yaml file for each specified or discovered official postgresversion"
  echo " "
  echo "build-all.sh [options]"
  echo " "
  echo "options:"
  echo "-h, --help"
  echo "-r, --registry=DOCKER_REGISTRY             specify docker registry (default: biutiful)"
  echo "-i, --image=IMG                            specify image name (default: kubedb-postgis)"
  echo "    --postgres-versions=POSTGRES_VERSIONs  specify official postgresversions separated by comma (default: discovery all official postgresversions)"
  echo "    --postgis-version=POSTGIS_VERSION      specify postgis version (default: 2.5.2)"
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -r)
      shift
      if [[ $# -gt 0 ]]
      then
        DOCKER_REGISTRY=$1
      else
        echo "no registry specified"
        exit 1
      fi
      shift
      ;;
    --registry*)
      DOCKER_REGISTRY=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    -i)
      shift
      if [[ $# -gt 0 ]]
      then
        IMG=$1
      else
        echo "no image specified"
        exit 1
      fi
      shift
      ;;
    --image=*)
      IMG=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    --postgres-versions=*)
      POSTGRES_VERSIONS=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    --postgis-version=*)
      POSTGIS_VERSION=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    *)
      echo "Error: unknow flage:" $1
      usage
      exit 1
      ;;
  esac
done

discovery_postgres_versions() {
  if ! postgres_versions=( $(kubectl get postgresversions -o go-template='{{range .items}}{{ .metadata.name }}{{"\n"}}{{end}}' 2>/dev/null) )
  then
    echo "Does the server have a resource type \"postgresversions\"?" >&2
    exit 2
  fi
}

build() {
  if ! postgres_version=$(kubectl get postgresversion "$1" -o go-template='{{ .metadata.name }};{{ .spec.db.image }};{{ if .spec.deprecated }}{{ .spec.deprecated }}{{ else }}false{{ end }}' 2>/dev/null)
  then
    echo "Is there a postgresversion called '$1'?" >&2
    exit 1
  fi

  arr=( $(echo "${postgres_version}" | sed "s/[;:]/ /g") )
  name=${arr[0]}
  img=${arr[1]}
  tag=${arr[2]}
  deprecated=${arr[3]}

  if [[ "$deprecated" == "true" ]]; then
    echo "The postgresversion '$name' is deprecated, ignore it."
  elif [[ "$img" != "kubedb/postgres" ]]; then
    echo "The postgres image '$img' of postgresversion '$name' is not official, ignore it."
  else
    pushd "$ROOT"

    mkdir -p "$name"

    echo "Build the biutiful/kubedb-postgis:$tag docker image..."
    ./build.sh --target-path=$name --docker-registry=$DOCKER_REGISTRY --image=$IMG --postgres-version=$tag --postgis-version=$POSTGIS_VERSION
    echo "Done."

    echo "Generate the postgresversion yaml file..."
    template=$(kubectl get postgresversion "$name" -o go-template='---
apiVersion: catalog.kubedb.com/v1alpha1
kind: PostgresVersion
metadata:
  name: postgis-{{ .metadata.name }}
spec:
  version: "{{ .spec.version }}"
  db:
    image: biutiful/kubedb-postgis:%%TAG%%
  exporter:
    image: {{ .spec.exporter.image }}
  tools:
    image: {{ .spec.tools.image }}
  podSecurityPolicies:
    databasePolicyName: "{{ .spec.podSecurityPolicies.databasePolicyName }}"
    snapshotterPolicyName: "{{ .spec.podSecurityPolicies.snapshotterPolicyName }}"     
')
    echo "$template" | sed "s!%%TAG%%!$tag!g" >> ./$name/postgresversion.yaml
    echo "Done"

    popd
  fi
}

build_all() {
  postgres_versions=( $(echo "${POSTGRES_VERSIONS}" | sed "s/,/ /g") )
  if [[ "${#postgres_versions[@]}" -eq 0 ]]
  then
    discovery_postgres_versions
  fi

  if [[ "${#postgres_versions[@]}" -eq 0 ]]
  then
    "No specified or discovered postgresversions, abort builing!"
    exit 0
  fi

  for v in "${postgres_versions[@]}"
  do
    build "$v"
  done
}

build_all $@
