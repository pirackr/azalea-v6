# Bootstrap Guide

Initial setup for bare metal hosts before full Ansible configuration.

## Prerequisites

- Ubuntu 24.04 installed on bare metal hosts
- SSH access with password auth enabled
- User with sudo privileges on each host

## Files

```
bootstrap/
├── ansible/
│   ├── inventory/
│   │   ├── bootstrap.yml   # IPs for initial password auth
│   │   └── hosts.yml       # Production inventory (after bootstrap)
│   └── playbooks/
│       └── bootstrap.yml   # Creates deploy user + injects SSH key
├── scripts/
│   └── decrypt-key.sh      # Decrypt the SSH private key
└── README.md               # This file
```

## Step 1: Update Bootstrap Inventory

Edit `ansible/inventory/bootstrap.yml` with your host IPs:

```yaml
bare_metal:
  hosts:
    golden-savanna:
      ansible_host: 192.168.4.150  # Your actual IP
    misty-bamboo:
      ansible_host: 192.168.4.151  # Your actual IP
```

## Step 2: Run Bootstrap Playbook

From the project root:

```bash
# Enter dev environment
nix develop

# Run bootstrap with password auth
cd bootstrap/ansible
ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap.yml -u <your-user> -kK
```

Flags:
- `-u <your-user>`: SSH username on the hosts
- `-k`: Prompt for SSH password
- `-K`: Prompt for sudo password

This will:
1. Create a `deploy` user on each host
2. Add the SSH public key to `deploy`'s authorized_keys
3. Configure passwordless sudo for `deploy`

## Step 3: Decrypt SSH Key

After bootstrap, decrypt the private key for future use:

```bash
./scripts/decrypt-key.sh
```

The decrypted key will be at `secrets/deploy_key` (gitignored).

## Step 4: Verify Access

Test key-based SSH access:

```bash
ssh -i secrets/deploy_key deploy@golden-savanna
ssh -i secrets/deploy_key deploy@misty-bamboo
```

## Step 5: Continue with Full Setup

Now you can run the full Ansible playbooks:

```bash
cd bootstrap/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## SSH Key Management

| File | Description | Git |
|------|-------------|-----|
| `secrets/deploy_key.age` | Encrypted private key | Committed |
| `secrets/deploy_key.pub` | Public key | Committed |
| `secrets/deploy_key` | Decrypted private key | Ignored |

To re-encrypt the key (if regenerating):

```bash
age -r age1gyjyj6vlv32rxxgsz5fdlfkgj92redq42nlhf798df9f05pcrgsqa0lx0u \
    -o secrets/deploy_key.age secrets/deploy_key
```

## Troubleshooting

**"Permission denied" during bootstrap:**
- Verify the username and password
- Ensure the user has sudo privileges

**"Host key verification failed":**
- First time connecting, accept the host key
- Or use `ANSIBLE_HOST_KEY_CHECKING=False`

**Can't decrypt key:**
- Ensure age key exists at `~/.config/sops/age/keys.txt`
- Verify it matches the public key in `.sops.yaml`
