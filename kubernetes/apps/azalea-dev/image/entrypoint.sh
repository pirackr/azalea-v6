#!/bin/bash
set -euo pipefail

mkdir -p /var/run/sshd

if [[ ! -x /home/pirackr/.nix-profile/bin/nix ]]; then
  su - pirackr -c "curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh"
  su - pirackr -c "sh /tmp/nix-install.sh --no-daemon"
  rm -f /tmp/nix-install.sh
fi

if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  ssh-keygen -A
fi

if [[ -d /home/pirackr/.ssh ]]; then
  chmod 700 /home/pirackr/.ssh
  if [[ -f /home/pirackr/.ssh/authorized_keys && -w /home/pirackr/.ssh/authorized_keys ]]; then
    chmod 600 /home/pirackr/.ssh/authorized_keys
  fi
fi

exec /usr/sbin/sshd -D -e
