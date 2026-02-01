FROM node:20-bookworm-slim

ARG USERNAME=pirackr
ARG UID=1000
ARG GID=1000

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    libfido2-1 \
    openssh-client \
    openssh-server \
    ripgrep \
    unzip \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${GID} ${USERNAME} \
  && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

RUN mkdir -p /nix \
  && chown ${UID}:${GID} /nix

RUN curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh \
  && su - ${USERNAME} -c "sh /tmp/nix-install.sh --no-daemon" \
  && rm /tmp/nix-install.sh

RUN printf '%s\n' '. /home/pirackr/.nix-profile/etc/profile.d/nix.sh' > /etc/profile.d/nix.sh

RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    opencode-ai

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sshd_config /etc/ssh/sshd_config

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
