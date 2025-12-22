# Azalea v6

Home lab infrastructure - Kubernetes on bare metal with VMs.

## Quick Start

```bash
# Enter dev environment
nix develop

# Bootstrap bare metal hosts (first time only)
cd bootstrap/ansible
ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap.yml -u <user> -kK

# Decrypt SSH key
./bootstrap/scripts/decrypt-key.sh

# Run full setup
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Architecture

| Host | Specs | Role |
|------|-------|------|
| `golden-savanna` | 6c/12t, 32GB, 512GB | Primary hypervisor |
| `misty-bamboo` | 4c/8t, 32GB, 256GB | Secondary hypervisor |

| VM | RAM | vCPU | Role |
|----|-----|------|------|
| `sleepy-koala` | 8GB | 4 | K8s control-plane |
| `lazy-panda` | 24GB | 8 | K8s worker |
| `chunky-wombat` | 16GB | 4 | K8s worker |
| `fancy-penguin` | 16GB | 4 | K8s worker |

## Directory Structure

```
azalea-v6/
├── bootstrap/          # Initial host setup
│   ├── ansible/        # Playbooks & roles
│   └── scripts/        # Helper scripts
├── kubernetes/         # K8s manifests (FluxCD)
│   ├── infrastructure/ # Cluster infra
│   └── apps/           # Applications
├── terraform/          # VM provisioning
├── secrets/            # Encrypted secrets
└── docs/               # Architecture docs
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Full system design
- [Bootstrap Guide](bootstrap/README.md) - Initial setup steps

## Tech Stack

- **OS**: Ubuntu 24.04
- **Virtualization**: KVM/libvirt
- **Orchestration**: Kubernetes (kubeadm)
- **CNI**: Cilium
- **GitOps**: FluxCD
- **Networking**: Tailscale
- **Secrets**: SOPS + age
