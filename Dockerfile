FROM garethr/kubeval:latest

RUN apk --no-cache add curl bash git openssh-client jq coreutils

# Add Kustomize
RUN curl -L --output /tmp/kustomize_v3.3.0_linux_amd64.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.3.0/kustomize_v3.3.0_linux_amd64.tar.gz \
  && echo "4b49e1bbdb09851f11bb81081bfffddc7d4ad5f99b4be7ef378f6e3cf98d42b6  /tmp/kustomize_v3.3.0_linux_amd64.tar.gz" | sha256sum -c \
  && tar -xvzf /tmp/kustomize_v3.3.0_linux_amd64.tar.gz -C /usr/local/bin \
  && chmod +x /usr/local/bin/kustomize

COPY src/deps.sh /deps.sh
RUN /deps.sh

COPY src/hrval.sh /usr/local/bin/hrval.sh
COPY src/hrval-all.sh /usr/local/bin/hrval
COPY src/kustomize-validate.sh /usr/local/bin/kustomize-validate

COPY README.md /

ENTRYPOINT ["/bin/bash", "-c"]
