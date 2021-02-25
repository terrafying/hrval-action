FROM garethr/kubeval:latest

RUN apk --no-cache add curl bash git openssh-client jq coreutils

ARG KUSTOMIZE_VERSION=v3.8.8
ARG KUSTOMIZE_URL=https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.8.8/kustomize_v3.8.8_linux_amd64.tar.gz

# Add Kustomize
RUN curl -L --output /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz \
  && echo "175938206f23956ec18dac3da0816ea5b5b485a8493a839da278faac82e3c303 /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" | sha256sum -c \
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
