FROM node:20-bookworm-slim

ARG USERNAME=pirackr
ARG UID=1000
ARG GID=1000

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    gh \
    git \
    libfido2-1 \
    openssh-client \
    openssh-server \
    ripgrep \
    unzip \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

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

RUN mkdir -p /nix \
  && chown ${UID}:${GID} /nix

RUN curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh \
  && su - ${USERNAME} -c "sh /tmp/nix-install.sh --no-daemon" \
  && rm /tmp/nix-install.sh

RUN printf '%s\n' 'if [ -e /home/pirackr/.nix-profile/etc/profile.d/nix.sh ]; then' \
  '  . /home/pirackr/.nix-profile/etc/profile.d/nix.sh' \
  'fi' > /etc/profile.d/nix.sh

RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    opencode-ai

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sshd_config /etc/ssh/sshd_config

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
