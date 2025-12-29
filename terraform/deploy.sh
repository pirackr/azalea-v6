#!/bin/bash
# OpenTofu deployment helper for Azalea v6
# Deploys VMs to remote hosts via SSH from local machine
#
# Usage: ./deploy.sh <host> <action>
#   host: golden-savanna | misty-bamboo
#   action: init | plan | apply | destroy | output

set -euo pipefail

# Ensure we're running in nix shell for age/tofu availability
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
    echo "  host: golden-savanna | misty-bamboo"
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

# Decrypt and source S3 credentials
if [[ -f "$PROJECT_ROOT/secrets/.s3.enc" ]]; then
    S3_CREDS=$(sops -d --output-type json "$PROJECT_ROOT/secrets/.s3.enc" | jq -r '.data')
    eval "$S3_CREDS"
    echo "✓ Loaded S3 credentials"
else
    echo "Error: S3 credentials not found at $PROJECT_ROOT/secrets/.s3.enc"
    exit 1
fi

# Load SSH public key
SSH_PUB_KEY_FILE="$PROJECT_ROOT/secrets/deploy_key.pub"
if [[ ! -f "$SSH_PUB_KEY_FILE" ]]; then
    echo "Error: SSH public key not found at $SSH_PUB_KEY_FILE"
    exit 1
fi
export TF_VAR_ssh_public_key=$(cat "$SSH_PUB_KEY_FILE")
echo "✓ Loaded SSH public key"

# Decrypt SSH private key for libvirt connection
SSH_PRIV_KEY_FILE="$PROJECT_ROOT/secrets/deploy_key"
if [[ ! -f "$SSH_PRIV_KEY_FILE" ]]; then
    echo "Decrypting SSH private key..."
    "$PROJECT_ROOT/bootstrap/scripts/decrypt-key.sh" > "$SSH_PRIV_KEY_FILE"
    chmod 600 "$SSH_PRIV_KEY_FILE"
fi
export TF_VAR_ssh_private_key_path="$SSH_PRIV_KEY_FILE"
echo "✓ Loaded SSH private key"

# Decrypt and load Tailscale auth key
TAILSCALE_KEY=$("$PROJECT_ROOT/bootstrap/scripts/decrypt-tailscale-key.sh")
if [[ -z "$TAILSCALE_KEY" ]]; then
    echo "Error: Failed to decrypt Tailscale auth key"
    exit 1
fi
export TF_VAR_tailscale_authkey="$TAILSCALE_KEY"
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
