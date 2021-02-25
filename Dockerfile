FROM garethr/kubeval:latest

RUN apk --no-cache add curl bash git openssh-client jq coreutils

ARG KUSTOMIZE_VERSION=v4.0.1

# Add Kustomize
RUN curl -L --output /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz \
  && tar -xvzf /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz -C /usr/local/bin \
  && chmod +x /usr/local/bin/kustomize

COPY src/deps.sh /deps.sh
RUN /deps.sh

COPY src/flux-install.sh /flux-install.sh
RUN /flux-install.sh

COPY src/hrval.sh /usr/local/bin/hrval.sh
COPY src/hrval-all.sh /usr/local/bin/hrval
COPY src/kustomize-validate.sh /usr/local/bin/kustomize-validate

COPY README.md /

ENTRYPOINT ["/bin/bash", "-c"]
