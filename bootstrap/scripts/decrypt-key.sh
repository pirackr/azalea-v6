#!/usr/bin/env bash
# Decrypt the deploy SSH key for use
#
# Usage: ./decrypt-key.sh
# The decrypted key will be at secrets/deploy_key (gitignored)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETS_DIR="$PROJECT_ROOT/secrets"
AGE_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

if [[ ! -f "$AGE_KEY" ]]; then
    echo "Error: Age key not found at $AGE_KEY"
    echo "Generate one with: age-keygen -o ~/.config/sops/age/keys.txt"
    exit 1
fi

if [[ ! -f "$SECRETS_DIR/deploy_key.age" ]]; then
    echo "Error: Encrypted key not found at $SECRETS_DIR/deploy_key.age"
    exit 1
fi

echo "Decrypting deploy key..."
age -d -i "$AGE_KEY" -o "$SECRETS_DIR/deploy_key" "$SECRETS_DIR/deploy_key.age"
chmod 600 "$SECRETS_DIR/deploy_key"

echo "Done! Key available at: secrets/deploy_key"
echo ""
echo "Usage:"
echo "  ssh -i secrets/deploy_key deploy@<host>"
echo "  ansible-playbook -i inventory/hosts.yml playbooks/site.yml"
