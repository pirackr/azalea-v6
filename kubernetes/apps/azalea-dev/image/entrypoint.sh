#!/bin/bash
set -euo pipefail

mkdir -p /var/run/sshd

if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  ssh-keygen -A
fi

if [[ -d /home/pirackr/.ssh ]]; then
  chmod 700 /home/pirackr/.ssh
  if [[ -f /home/pirackr/.ssh/authorized_keys && -w /home/pirackr/.ssh/authorized_keys ]]; then
    chmod 600 /home/pirackr/.ssh/authorized_keys
  fi
fi

su -p -s /bin/bash -c "opencode web --hostname 0.0.0.0 --port 3000" pirackr &

exec /usr/sbin/sshd -D -e
