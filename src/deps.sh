#!/usr/bin/env bash

set -o errexit

KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
YQ_VERSION=3.3.2
HELM_VERSION=v3.4.0
HELM_S3_VERSION=0.10.0
FLUX_VERSION=1.21.0

# Install kubectl stable
curl -sL https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# yq (jq for yaml)
curl -sL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Helm v3
curl -sSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /bin/helm && rm -rf linux-amd64
ln -s /bin/helm /bin/helmv3

# Print helm version
helm version

# Helm S3 Plugin
helm plugin install https://github.com/hypnoglow/helm-s3.git --version $HELM_S3_VERSION

# FluxCD
curl -L https://github.com/fluxcd/flux/releases/download/${FLUX_VERSION}/fluxctl_linux_amd64 -o /usr/local/bin/fluxctl \
 && chmod +x /usr/local/bin/fluxctl

# Kfilt - utility to filter kustomize output by name, type
curl -L https://github.com/ryane/kfilt/releases/download/v0.0.5/kfilt_0.0.5_linux_amd64 --output /usr/local/bin/kfilt
chmod +x /usr/local/bin/kfilt