#!/bin/bash
# OpenTofu deployment helper for Azalea v6
# Deploys VMs to remote hosts via SSH from local machine
#
# Usage: ./deploy.sh <host> <action>
#   host: golden-savanna | misty-bamboo | lush-forest
#   action: init | plan | apply | destroy | output
#
# Secrets are managed via Doppler (project: azalea, config: main)

set -euo pipefail

# Ensure we're running in nix shell for tofu availability
if [ -z "${IN_NIX_SHELL:-}" ]; then
    echo "Not in nix shell, entering nix develop environment..."
    SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    cd "$PROJECT_ROOT"
    exec nix develop --command "$SCRIPT_PATH" "$@"
fi

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <host> <action>"
    echo "  host: golden-savanna | misty-bamboo | lush-forest"
    echo "  action: init | plan | apply | destroy | output"
    exit 1
fi

HOST=$1
ACTION=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate host
if [[ ! -d "$SCRIPT_DIR/hosts/$HOST" ]]; then
    echo "Error: Unknown host '$HOST'"
    echo "Available hosts:"
    ls -1 "$SCRIPT_DIR/hosts"
    exit 1
fi

# Check if running inside Doppler (secrets already injected)
if [[ -z "${DEPLOY_KEY:-}" ]]; then
    echo "Not running inside Doppler, re-executing with doppler run..."
    exec doppler run --project azalea --config main -- "$0" "$@"
fi

echo "✓ Secrets loaded from Doppler"

# Load SSH public key (not sensitive, kept as file)
SSH_PUB_KEY_FILE="$PROJECT_ROOT/secrets/deploy_key.pub"
if [[ ! -f "$SSH_PUB_KEY_FILE" ]]; then
    echo "Error: SSH public key not found at $SSH_PUB_KEY_FILE"
    exit 1
fi
export TF_VAR_ssh_public_key=$(cat "$SSH_PUB_KEY_FILE")
echo "✓ Loaded SSH public key"

# Write SSH private key from Doppler to temp file (Terraform needs file path)
SSH_PRIV_KEY_FILE=$(mktemp)
trap "rm -f $SSH_PRIV_KEY_FILE" EXIT
echo "$DEPLOY_KEY" > "$SSH_PRIV_KEY_FILE"
chmod 600 "$SSH_PRIV_KEY_FILE"
export TF_VAR_ssh_private_key_path="$SSH_PRIV_KEY_FILE"
echo "✓ Loaded SSH private key"

# Map Doppler secret to Terraform variable
export TF_VAR_tailscale_authkey="$TAILSCALE_AUTHKEY"
echo "✓ Loaded Tailscale auth key"

# Verify SSH connectivity to remote host
echo "Testing SSH connection to $HOST..."
if ! ssh -i "$SSH_PRIV_KEY_FILE" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "deploy@$HOST" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo "Error: Cannot connect to deploy@$HOST via SSH"
    echo "Make sure:"
    echo "  1. Host is reachable via Tailscale (try: tailscale status)"
    echo "  2. Bootstrap playbook has been run on $HOST"
    echo "  3. SSH key is correct: $SSH_PRIV_KEY_FILE"
    exit 1
fi
echo "✓ SSH connection OK"

# Change to host directory
cd "$SCRIPT_DIR/hosts/$HOST"

# Execute OpenTofu
echo ""
echo "=== Running OpenTofu $ACTION for $HOST ==="
echo "    Connection: qemu+ssh://deploy@$HOST/system"
echo ""

case $ACTION in
    init)
        # Pass through any additional flags (like -reconfigure)
        shift 2  # Remove host and action args
        tofu init "$@"
        ;;
    plan)
        tofu plan
        ;;
    apply)
        tofu apply -auto-approve
        ;;
    destroy)
        tofu destroy
        ;;
    output)
        tofu output
        ;;
    *)
        echo "Error: Unknown action '$ACTION'"
        echo "Valid actions: init, plan, apply, destroy, output"
        exit 1
        ;;
esac
