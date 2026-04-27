FROM node:20-bookworm-slim

ARG USERNAME=pirackr
ARG UID=1000
ARG GID=1000

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    direnv \
    gh \
    git \
    jq \
    libfido2-1 \
    openssh-client \
    openssh-server \
    ripgrep \
    shellcheck \
    vim \
    unzip \
    wget \
    xz-utils \
    ansible \
    ansible-lint \
    age \
    gnupg \
  && rm -rf /var/lib/apt/lists/*

RUN set -e; \
  arch="$(dpkg --print-architecture)"; \
  case "${arch}" in \
    amd64|arm64) ;; \
    *) echo "Unsupported arch: ${arch}" >&2; exit 1 ;; \
  esac; \
  kubectl_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"; \
  curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${arch}/kubectl"; \
  chmod +x /usr/local/bin/kubectl; \
  helm_version="$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)"; \
  curl -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-${helm_version}-linux-${arch}.tar.gz"; \
  tar -xzf /tmp/helm.tar.gz -C /tmp; \
  mv /tmp/linux-${arch}/helm /usr/local/bin/helm; \
  rm -rf /tmp/helm.tar.gz /tmp/linux-${arch}; \
  flux_version="$(curl -fsSL https://api.github.com/repos/fluxcd/flux2/releases/latest | jq -r .tag_name)"; \
  curl -fsSLo /tmp/flux.tar.gz "https://github.com/fluxcd/flux2/releases/download/${flux_version}/flux_${flux_version#v}_linux_${arch}.tar.gz"; \
  tar -xzf /tmp/flux.tar.gz -C /tmp; \
  mv /tmp/flux /usr/local/bin/flux; \
  rm -f /tmp/flux.tar.gz; \
  kustomize_tag="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | jq -r .tag_name)"; \
  kustomize_version="${kustomize_tag#kustomize/}"; \
  curl -fsSLo /tmp/kustomize.tar.gz "https://github.com/kubernetes-sigs/kustomize/releases/download/${kustomize_tag}/kustomize_${kustomize_version}_linux_${arch}.tar.gz"; \
  tar -xzf /tmp/kustomize.tar.gz -C /usr/local/bin; \
  rm -f /tmp/kustomize.tar.gz; \
  kubeconform_version="$(curl -fsSL https://api.github.com/repos/yannh/kubeconform/releases/latest | jq -r .tag_name)"; \
  curl -fsSLo /tmp/kubeconform.tar.gz "https://github.com/yannh/kubeconform/releases/download/${kubeconform_version}/kubeconform-linux-${arch}.tar.gz"; \
  tar -xzf /tmp/kubeconform.tar.gz -C /usr/local/bin kubeconform; \
  rm -f /tmp/kubeconform.tar.gz; \
  opentofu_version="$(curl -fsSL https://api.github.com/repos/opentofu/opentofu/releases/latest | jq -r .tag_name)"; \
  curl -fsSLo /tmp/opentofu.tar.gz "https://github.com/opentofu/opentofu/releases/download/${opentofu_version}/tofu_${opentofu_version#v}_linux_${arch}.tar.gz"; \
  tar -xzf /tmp/opentofu.tar.gz -C /usr/local/bin tofu; \
  rm -f /tmp/opentofu.tar.gz; \
  curl -fsSLo /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"; \
  chmod +x /usr/local/bin/cloudflared; \
  yq_version="$(curl -fsSL https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r .tag_name)"; \
  curl -fsSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${yq_version}/yq_linux_${arch}"; \
  chmod +x /usr/local/bin/yq; \
  curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh | sh

RUN if getent group "${GID}" >/dev/null; then \
    group_name="$(getent group "${GID}" | cut -d: -f1)"; \
  else \
    groupadd -g "${GID}" "${USERNAME}"; \
    group_name="${USERNAME}"; \
  fi \
  && if id -u "${USERNAME}" >/dev/null 2>&1; then \
    usermod -g "${group_name}" "${USERNAME}"; \
  elif getent passwd "${UID}" >/dev/null; then \
    existing_user="$(getent passwd "${UID}" | cut -d: -f1)"; \
    usermod -l "${USERNAME}" "${existing_user}"; \
    usermod -d "/home/${USERNAME}" -m "${USERNAME}"; \
    if [ "${group_name}" != "${USERNAME}" ] && getent group "${group_name}" >/dev/null; then \
      usermod -g "${group_name}" "${USERNAME}"; \
    else \
      existing_group="$(getent group "${GID}" | cut -d: -f1)"; \
      groupmod -n "${USERNAME}" "${existing_group}"; \
    fi; \
  else \
    useradd -m -u "${UID}" -g "${group_name}" -s /bin/bash "${USERNAME}"; \
  fi \
  && passwd -d "${USERNAME}" \
  && usermod -U "${USERNAME}"

# Install AI coding tools
RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    happy-coder \
    opencode-ai@1.14.28

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sshd_config /etc/ssh/sshd_config

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
