# Azalea v6 - VM Provisioning with OpenTofu

OpenTofu configuration for provisioning KVM/libvirt VMs on bare metal hosts.

## Architecture

```
terraform/
├── modules/vm/          # Reusable VM module with cloud-init
├── hosts/
│   ├── golden-savanna/  # sleepy-koala, lazy-panda
│   └── misty-bamboo/    # chunky-wombat, fancy-penguin
└── deploy.sh            # Helper script
```

## Prerequisites

1. **Bare metal hosts configured**:
   ```bash
   cd bootstrap/ansible
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml
   ```

2. **Download Ubuntu cloud image**:
   ```bash
   mkdir -p terraform/images
   wget -O terraform/images/ubuntu-24.04-server-cloudimg-amd64.img \
     https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img
   ```

3. **Secrets in place**:
   - `secrets/.s3.enc` - Encrypted R2 credentials for state storage
   - `secrets/deploy_key.pub` - SSH public key
   - `secrets/tailscale-authkey.age` - Encrypted Tailscale key

4. **OpenTofu installed** (via `nix develop` at project root)

## VM Specifications

### golden-savanna
| VM | vCPU | RAM | Disk | Role |
|----|------|-----|------|------|
| sleepy-koala | 4 | 8GB | 80GB | K8s control plane |
| lazy-panda | 8 | 24GB | 200GB | K8s worker |

### misty-bamboo
| VM | vCPU | RAM | Disk | Role |
|----|------|-----|------|------|
| chunky-wombat | 4 | 16GB | 100GB | K8s worker |
| fancy-penguin | 4 | 16GB | 100GB | K8s worker |

## Usage

Deploy VMs to remote hosts from your local machine via SSH.

### Prerequisites Check

```bash
# 1. Verify SSH connectivity to hosts
ssh deploy@golden-savanna
ssh deploy@misty-bamboo

# 2. Load SSH key if needed
ssh-add ~/.ssh/id_ed25519  # or your key
```

### Deploy VMs on golden-savanna

```bash
# From your local machine
cd terraform

# Initialize (first time only)
./deploy.sh golden-savanna init

# Plan
./deploy.sh golden-savanna plan

# Apply
./deploy.sh golden-savanna apply

# Check outputs
./deploy.sh golden-savanna output
```

### Deploy VMs on misty-bamboo

```bash
# Same process, different host
./deploy.sh misty-bamboo init
./deploy.sh misty-bamboo plan
./deploy.sh misty-bamboo apply
```

The script will:
1. Load S3 credentials from `secrets/.s3`
2. Load SSH public key from `secrets/deploy_key.pub`
3. Decrypt SSH private key for libvirt connection
4. Decrypt Tailscale auth key
5. Test SSH connection to remote host
6. Connect to libvirt via `qemu+ssh://deploy@<host>/system`
7. Execute OpenTofu action

## Cloud-init Process

VMs are provisioned with cloud-init which:
1. Sets hostname
2. Creates `deploy` user with SSH key
3. Installs essential packages
4. Installs and configures Tailscale
5. Hardens SSH (no password auth)
6. Enables automatic security updates
7. Reboots to apply changes

**After provisioning**: VMs will be accessible via Tailscale hostnames:
- `ssh deploy@sleepy-koala`
- `ssh deploy@lazy-panda`
- `ssh deploy@chunky-wombat`
- `ssh deploy@fancy-penguin`

## State Management

OpenTofu state is stored in Cloudflare R2 (S3-compatible):
- Bucket: `azalea-terraform-state`
- Keys:
  - `hosts/golden-savanna/terraform.tfstate`
  - `hosts/misty-bamboo/terraform.tfstate`

Note: OpenTofu is fully compatible with Terraform state files.

## Destroy VMs


## Troubleshooting

**VMs not getting IP**: Check libvirt network is running:
```bash
virsh net-list
virsh net-start default
```

**Cloud-init not running**: Check console:
```bash
virsh console <vm-name>
# Press Ctrl+] to exit
```

**Tailscale not connecting**: Check cloud-init logs in VM:
```bash
ssh deploy@<vm-ip>
sudo cloud-init status
sudo journalctl -u cloud-init
```

## Next Steps

After VMs are provisioned:
1. Verify Tailscale connectivity: `tailscale status`
2. Install Kubernetes using kubeadm (next phase)
3. Bootstrap K8s cluster
