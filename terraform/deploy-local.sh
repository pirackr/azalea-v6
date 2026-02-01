#!/bin/bash
# OpenTofu deployment helper for Azalea v6 (Non-Nix version)
#
# Usage: ./deploy.sh <target> <action>
#   target: golden-savanna | misty-bamboo | lush-forest | cloudflare
#   action: init | plan | apply | destroy | output
#
# Secrets are managed via Doppler (project: azalea, config: main)
# Requires: tofu (or terraform) and doppler CLI installed

set -euo pipefail

# Check if doppler CLI is available
if ! command -v doppler >/dev/null 2>&1; then
    echo "Error: doppler CLI not found in PATH"
    echo "Please install Doppler CLI: https://docs.doppler.com/docs/cli"
    exit 1
fi

# Check if we're already running inside Doppler (secrets injected)
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]] && [[ -z "${DEPLOY_KEY:-}" ]]; then
    echo "Not running with Doppler secrets, re-executing with doppler run..."
    SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
    exec doppler run --project azalea --config main -- "$SCRIPT_PATH" "$@"
fi

# Detect which binary to use: tofu (preferred) or terraform
TF_BINARY="tofu"
if ! command -v tofu >/dev/null 2>&1; then
    if command -v terraform >/dev/null 2>&1; then
        TF_BINARY="terraform"
        echo "✓ Using terraform (tofu not found)"
    else
        echo "Error: Neither tofu nor terraform found in PATH"
        echo "Please install OpenTofu: https://opentofu.org/docs/intro/install/"
        exit 1
    fi
else
    echo "✓ Using tofu"
fi

echo "✓ Secrets loaded from Doppler"

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <target> <action>"
    echo "  target: golden-savanna | misty-bamboo | lush-forest | cloudflare"
    echo "  action: init | plan | apply | destroy | output"
    exit 1
fi

TARGET=$1
ACTION=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine target directory
if [[ "$TARGET" == "cloudflare" ]]; then
    TARGET_DIR="$SCRIPT_DIR/cloudflare"
elif [[ -d "$SCRIPT_DIR/hosts/$TARGET" ]]; then
    TARGET_DIR="$SCRIPT_DIR/hosts/$TARGET"
else
    echo "Error: Unknown target '$TARGET'"
    echo "Available targets:"
    echo "  cloudflare"
    ls -1 "$SCRIPT_DIR/hosts" 2>/dev/null | sed 's/^/  /' || echo "  (no hosts found)"
    exit 1
fi

# Target-specific setup
if [[ "$TARGET" == "cloudflare" ]]; then
    # Cloudflare target - map Doppler secrets to TF variables
    if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        echo "Error: CLOUDFLARE_API_TOKEN not found in Doppler secrets"
        exit 1
    fi
    export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
    export TF_VAR_cloudflare_zone_id="$CLOUDFLARE_ZONE_ID"
    export TF_VAR_tunnel_secret="$CLOUDFLARE_TUNNEL_SECRET"
    echo "✓ Loaded Cloudflare credentials"
else
    # Host targets - need SSH keys and Tailscale
    SSH_PUB_KEY_FILE="$PROJECT_ROOT/secrets/deploy_key.pub"
    if [[ ! -f "$SSH_PUB_KEY_FILE" ]]; then
        echo "Error: SSH public key not found at $SSH_PUB_KEY_FILE"
        exit 1
    fi
    export TF_VAR_ssh_public_key=$(cat "$SSH_PUB_KEY_FILE")
    echo "✓ Loaded SSH public key"

    # Write SSH private key from Doppler to temp file (Terraform needs file path)
    if [[ -z "${DEPLOY_KEY:-}" ]]; then
        echo "Error: DEPLOY_KEY not found in Doppler secrets"
        exit 1
    fi
    SSH_PRIV_KEY_FILE=$(mktemp)
    trap "rm -f $SSH_PRIV_KEY_FILE" EXIT
    echo "$DEPLOY_KEY" > "$SSH_PRIV_KEY_FILE"
    chmod 600 "$SSH_PRIV_KEY_FILE"
    export TF_VAR_ssh_private_key_path="$SSH_PRIV_KEY_FILE"
    echo "✓ Loaded SSH private key"

    # Map Doppler secret to Terraform variable
    if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
        echo "Error: TAILSCALE_AUTHKEY not found in Doppler secrets"
        exit 1
    fi
    export TF_VAR_tailscale_authkey="$TAILSCALE_AUTHKEY"
    echo "✓ Loaded Tailscale auth key"

    # Verify SSH connectivity to remote host
    echo "Testing SSH connection to $TARGET..."
    if ! ssh -i "$SSH_PRIV_KEY_FILE" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "deploy@$TARGET" "echo 'SSH OK'" >/dev/null 2>&1; then
        echo "Error: Cannot connect to deploy@$TARGET via SSH"
        echo "Make sure:"
        echo "  1. Host is reachable via Tailscale (try: tailscale status)"
        echo "  2. Bootstrap playbook has been run on $TARGET"
        echo "  3. SSH key is correct"
        exit 1
    fi
    echo "✓ SSH connection OK"
fi

# Change to target directory
cd "$TARGET_DIR"

# Execute OpenTofu/Terraform
echo ""
echo "=== Running $TF_BINARY $ACTION for $TARGET ==="
echo ""

case $ACTION in
    init)
        # Pass through any additional flags (like -reconfigure)
        shift 2  # Remove host and action args
        $TF_BINARY init "$@"
        ;;
    plan)
        $TF_BINARY plan
        ;;
    apply)
        $TF_BINARY apply -auto-approve
        ;;
    destroy)
        $TF_BINARY destroy
        ;;
    output)
        $TF_BINARY output
        ;;
    *)
        echo "Error: Unknown action '$ACTION'"
        echo "Valid actions: init, plan, apply, destroy, output"
        exit 1
        ;;
esac
