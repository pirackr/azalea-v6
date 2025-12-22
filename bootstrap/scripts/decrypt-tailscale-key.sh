#!/usr/bin/env bash
# Decrypt the Tailscale auth key
#
# Usage: ./decrypt-tailscale-key.sh
# Output: prints the auth key to stdout (for use in ansible)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETS_DIR="$PROJECT_ROOT/secrets"
AGE_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

if [[ ! -f "$AGE_KEY" ]]; then
    echo "Error: Age key not found at $AGE_KEY" >&2
    exit 1
fi

if [[ ! -f "$SECRETS_DIR/tailscale-authkey.age" ]]; then
    echo "Error: Encrypted key not found at $SECRETS_DIR/tailscale-authkey.age" >&2
    exit 1
fi

# Decrypt and output to stdout
age -d -i "$AGE_KEY" "$SECRETS_DIR/tailscale-authkey.age"
