#!/usr/bin/env bash

set -euo pipefail

ROOT="$( dirname "${BASH_SOURCE[0]}" )"
TARGET_PATH=${TARGET_PATH:-}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-biutiful}
IMG=${IMG:-kubedb-postgis}
POSTGRES_VERSION=${POSTGRES_VERSION:-11.1-v2}
POSTGIS_VERSION=${POSTGIS_VERSION:-2.5.2}

usage() {
  echo "build.sh - build docker image to run Postgres with PostGIS"
  echo " "
  echo "build.sh [options]"
  echo " "
  echo "options:"
  echo "-h, --help"
  echo "-r, --registry=DOCKER_REGISTRY             specify docker registry (default: biutiful)"
  echo "-i, --image=IMG                            specify image name (default: kubedb-postgis)"
  echo "    --postgres-version=POSTGRES_VERSION    specify kubedb postgres image version (default: 11.1-v2)"
  echo "    --postgis-version=POSTGIS_VERSION      specify postgis version (default: 2.5.2)"
  echo "    --target-path=TARGET_PATH              specify destination path to build docker image (default: <postgres-version>)"
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
    --postgres-version=*)
      POSTGRES_VERSION=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    --postgis-version=*)
      POSTGIS_VERSION=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    --target-path=*)
      TARGET_PATH=$(echo $1 | sed -e 's/^[^=]*=//g')
      shift
      ;;
    *)
      echo "Error: unknow flage:" $1
      usage
      exit 1
      ;;
  esac
done

if [[ "$TARGET_PATH" == "" ]]; then
  TARGET_PATH="$POSTGRES_VERSION"
fi

generate_dockerfile() {
  pushd "$ROOT"

  mkdir -p $TARGET_PATH
  local cmd="sed 's!%%POSTGRES_VERSION%%!$POSTGRES_VERSION!g; s!%%POSTGIS_VERSION%%!$POSTGIS_VERSION!g' Dockerfile.template > "$TARGET_PATH/Dockerfile""
  echo $cmd; eval "$cmd"

  popd
}

build_docker() {
  pushd "$ROOT/$TARGET_PATH"

  local cmd="docker build --pull -t $DOCKER_REGISTRY/$IMG:$POSTGRES_VERSION ."
  echo $cmd; eval "$cmd"

  popd
}

build() {
  generate_dockerfile
  build_docker
}

echo "build docker image with:"
echo "  ROOT             = $ROOT"
echo "  TARGET_PATH      = $TARGET_PATH"
echo "  DOCKER_REGISTRY  = $DOCKER_REGISTRY"
echo "  IMG              = $IMG"
echo "  POSTGRES_VERSION = $POSTGRES_VERSION"
echo "  POSTGIS_VERSION  = $POSTGIS_VERSION"

build $@
