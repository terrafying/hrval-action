#!/usr/bin/env bash

set -o errexit

HELM_RELEASE=${1}
IGNORE_VALUES=${2}
KUBE_VER=${3-master}
HELM_VER=${4-v3}

if test ! -f "${HELM_RELEASE}"; then
  echo "\"${HELM_RELEASE}\" Helm release file not found!"
  exit 1
fi

echo "Processing ${HELM_RELEASE}"

function isHelmRelease {
  KIND=$(yq r ${1} kind)
  if [[ ${KIND} == "HelmRelease" ]]; then
      echo true
  else
    echo false
  fi
}

function download {
  # spec:
  # chart:
  #   spec:
  #     chart: ./charts/brivo-app
  #     sourceRef:
  #       kind: GitRepository
  #       name: flux-ops
  #       namespace: brivo-apps

  NEW_CHART_REPO=$(yq r ${1} spec.chart.spec.chart)
  CHART_REPO=$(yq r ${1} spec.chart.repository)
  if ! test -z "$NEW_CHART_REPO"; then
    CHART_REPO=$NEW_CHART_REPO
  fi

  NEW_CHART_NAME=$(yq r ${1} spec.chart.spec.sourceRef.name)
  CHART_NAME=$(yq r ${1} spec.chart.name)
  if ! test -z "$NEW_CHART_NAME"; then
    CHART_NAME=$NEW_CHART_NAME
  fi

  CHART_VERSION=$(yq r ${1} spec.chart.version)
  CHART_DIR=${2}/${CHART_NAME}

  CHART_REPO_MD5=`/bin/echo $CHART_REPO | /usr/bin/md5sum | cut -f1 -d" "`

  helm repo add ${CHART_REPO_MD5} ${CHART_REPO}
  helm repo update
  helm fetch --version ${CHART_VERSION} --untar ${CHART_REPO_MD5}/${CHART_NAME} --untardir ${2}
  
  echo ${CHART_DIR}
}


function fetch {
  cd ${1}
  git init -q
  git remote add origin ${3}
  git fetch -q origin
  git checkout -q ${4}
  cd ${5}
  echo ${2}
}


function clone {
  # ORIGIN=$(git rev-parse --show-toplevel)
  # echo "ORIGIN $ORIGIN"
  CHART_GIT_REPO=$(yq r ${1} spec.chart.git)
  echo "CHART_GIT_REPO $CHART_GIT_REPO"
  # RELEASE_GIT_REPO=$(git remote get-url origin)
  # echo "RELEASE_GIT_REPO $RELEASE_GIT_REPO"

  CHART_BASE_URL=$(basename $(echo "${CHART_GIT_REPO}" | sed -e 's/ssh:\/\///' -e 's/http:\/\///' -e 's/https:\/\///' -e 's/git@//' -e 's/:/\//') .git )
  # RELEASE_BASE_URL=$(basename $(echo "${RELEASE_GIT_REPO}" | sed -e 's/ssh:\/\///' -e 's/http:\/\///' -e 's/https:\/\///' -e 's/git@//' -e 's/:/\//') .git )

  echo "Chart Base url $CHART_BASE_URL"

  if [[ -n "${GITHUB_TOKEN}" ]]; then
    CHART_GIT_REPO="https://${GITHUB_TOKEN}:x-oauth-basic@${CHART_BASE_URL}"
  elif [[ -n "${BITBUCKET_OAUTH}" ]] && [[ CHART_BASE_URL == bitbucket* ]]; then
    CHART_GIT_REPO="https://${BITBUCKET_OAUTH}@${CHART_BASE_URL}"
  fi

  GIT_REF=$(yq r ${1} spec.chart.ref)
  CHART_PATH=$(yq r ${1} spec.chart.path)

  if [ ! -z ${3} ]; then
    # if [[ "${CHART_BASE_URL}" == "${RELEASE_BASE_URL}" ]] && [[ ${GIT_REF} == "${4}" ]]; then
    #   # Clone from the head repository branch/ref
    #   fetch ${2} ${2}/${CHART_PATH} ${RELEASE_GIT_REPO} ${3} ${ORIGIN}
    # else
      # Regular clone
      fetch ${2} ${2}/${CHART_PATH} ${CHART_GIT_REPO} ${GIT_REF} ${PWD}
    # fi
  else
      fetch ${2} ${2}/${CHART_PATH} ${CHART_GIT_REPO} ${GIT_REF} ${PWD}
  fi
}

function validate {
  if [[ $(isHelmRelease ${HELM_RELEASE}) == "false" ]]; then
    echo "\"${HELM_RELEASE}\" is not of kind HelmRelease!"
    exit 1
  fi

  TMPDIR=$(mktemp -d)

  NEW_CHART_NAME=$(yq r ${HELM_RELEASE} spec.chart.spec.sourceRef.name)
  CHART_NAME=$(yq r ${HELM_RELEASE} spec.chart.name)
  if ! test -z "$NEW_CHART_NAME"; then
    CHART_NAME=$NEW_CHART_NAME
  fi

  NEW_CHART_PATH=$(yq r ${HELM_RELEASE} spec.chart.spec.chart)
  CHART_PATH=$(yq r ${HELM_RELEASE} spec.chart.path)
  if ! test -z "$NEW_CHART_PATH"; then
    CHART_PATH=$NEW_CHART_PATH
  fi

  CHART_REPO=$(yq r ${HELM_RELEASE} spec.chart.git)

  if [[ -z "${CHART_PATH}" ]]; then
    echo "Downloading to ${TMPDIR}"
    CHART_DIR=$(download ${HELM_RELEASE} ${TMPDIR} ${HELM_VER}| tail -n1)
  elif [[ -d "${CHART_PATH}" ]]; then
    echo "Found chart at ${CHART_PATH}"
    CHART_DIR=$CHART_PATH
  else
    echo "Cloning to ${TMPDIR}"
    CHART_DIR=$(clone ${HELM_RELEASE} ${TMPDIR} ${HRVAL_HEAD_BRANCH} ${HRVAL_BASE_BRANCH} | tail -n1)
  fi

  HELM_RELEASE_NAME=$(yq r ${HELM_RELEASE} metadata.name)
  HELM_RELEASE_NAMESPACE=$(yq r ${HELM_RELEASE} metadata.namespace)

  if [[ ${IGNORE_VALUES} == "true" ]]; then
    echo "Ingnoring Helm release values"
    echo "" > ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml
  else
    echo "Extracting values to ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml"
    yq r ${HELM_RELEASE} spec.values > ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml
  fi

  echo "Writing Helm release to ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml"
  if [[ "${CHART_PATH}" ]]; then
    helm dependency build ${CHART_DIR}
  fi
  helm template ${HELM_RELEASE_NAME} ${CHART_DIR} \
    --namespace ${HELM_RELEASE_NAMESPACE} \
    --skip-crds=true \
    -f ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml > ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml


  echo "Validating Helm release ${HELM_RELEASE_NAME}.${HELM_RELEASE_NAMESPACE} against Kubernetes ${KUBE_VER}"
  kubeval --strict --ignore-missing-schemas --kubernetes-version ${KUBE_VER} ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml
}

validate
