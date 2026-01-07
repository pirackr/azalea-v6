#!/bin/bash
# Ansible wrapper for Azalea v6
# Injects secrets from Doppler and runs ansible-playbook
#
# Usage: ./run.sh <playbook> [ansible-playbook options]
#
# Examples:
#   ./run.sh playbooks/bootstrap.yml -i inventory/bootstrap.yml -u pirackr -kK
#   ./run.sh playbooks/site.yml -i inventory/hosts.yml --limit golden-savanna
#   ./run.sh playbooks/kubernetes.yml -i inventory/hosts.yml
#
# Secrets are managed via Doppler (project: azalea, config: main)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Ensure we're running in nix shell
if [ -z "${IN_NIX_SHELL:-}" ]; then
    echo "Not in nix shell, entering nix develop environment..."
    cd "$PROJECT_ROOT"
    exec nix develop --command "$SCRIPT_DIR/run.sh" "$@"
fi

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <playbook> [ansible-playbook options]"
    echo ""
    echo "Examples:"
    echo "  $0 playbooks/bootstrap.yml -i inventory/bootstrap.yml -u pirackr -kK"
    echo "  $0 playbooks/site.yml -i inventory/hosts.yml --limit golden-savanna"
    echo "  $0 playbooks/kubernetes.yml -i inventory/hosts.yml"
    exit 1
fi

# Check if running inside Doppler (secrets already injected)
if [[ -z "${DEPLOY_KEY:-}" ]]; then
    echo "Not running inside Doppler, re-executing with doppler run..."
    exec doppler run --project azalea --config main -- "$0" "$@"
fi

echo "✓ Secrets loaded from Doppler"

# Write SSH private key from Doppler to temp file
SSH_PRIV_KEY_FILE=$(mktemp)
trap "rm -f $SSH_PRIV_KEY_FILE" EXIT
echo "$DEPLOY_KEY" > "$SSH_PRIV_KEY_FILE"
chmod 600 "$SSH_PRIV_KEY_FILE"
export SSH_PRIVATE_KEY_FILE="$SSH_PRIV_KEY_FILE"
echo "✓ SSH private key ready"

# TAILSCALE_AUTHKEY is already set by Doppler
echo "✓ Tailscale auth key ready"

# Change to ansible directory
cd "$SCRIPT_DIR"

PLAYBOOK=$1
shift

echo ""
echo "=== Running Ansible Playbook: $PLAYBOOK ==="
echo ""

# Run ansible-playbook with the SSH key
ansible-playbook "$PLAYBOOK" \
    -e "ansible_ssh_private_key_file=$SSH_PRIV_KEY_FILE" \
    "$@"
