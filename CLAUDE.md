# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Azalea v6 is a home lab Kubernetes infrastructure project with VMs on bare metal hosts. Uses GitOps (FluxCD) for declarative cluster management.

## Hardware

| Hostname | Specs | Role |
|----------|-------|------|
| `golden-savanna` | 6c/12t, 32GB, 512GB SSD | Primary (control + workloads) |
| `misty-bamboo` | 4c/8t, 32GB, 256GB SSD | Worker (scale-up) |
| `lush-rainforest` | 4c/8t, 32GB, 256GB SSD | Worker (scale-up) |
| `wild-outback` | 16c/32t, 128GB | Burst (temporary) |

## K8s VMs (Animals)

| VM | Role | Host |
|----|------|------|
| `sleepy-koala` | K8s control-plane | golden-savanna |
| `lazy-panda` | K8s worker | golden-savanna |
| `chunky-wombat` | K8s worker | misty-bamboo |
| `fancy-penguin` | K8s worker | misty-bamboo |
| `grumpy-walrus` | K8s worker | lush-forest |
| `happy-dolphin` | K8s worker | lush-forest |

## Naming Convention

**Theme**: Zoo - Bare metal = Habitats, VMs = Animals

## Tech Stack

| Layer | Technology |
|-------|------------|
| Base OS | Ubuntu Server 24.04 |
| Virtualization | KVM/libvirt |
| Orchestration | Kubernetes (kubeadm) |
| CNI | Flannel (VXLAN over Tailscale) |
| GitOps | FluxCD |
| Ingress | Traefik |
| External Access | Cloudflare Tunnel |
| Mesh Network | Tailscale |
| Secrets | SOPS + age |
| IaC | OpenTofu (Terraform), Ansible |

## Commands

```bash
# Enter dev environment (required first)
nix develop

# --- Kubernetes / Flux ---
export KUBECONFIG=~/.kube/config-azalea
kubectl get nodes
kubectl get pods -A
k9s                                        # Terminal UI
flux check                                 # Verify FluxCD health
flux get all                               # View all Flux resources
flux reconcile kustomization apps --with-source    # Force sync apps
flux reconcile kustomization infrastructure --with-source

# --- Ansible (from bootstrap/ansible/) ---
# Bootstrap new bare metal host (first time, with password)
ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap.yml --limit <host> -u <user> -kK

# Configure hypervisor
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit <host> --tags hypervisor

# Deploy/update K8s cluster
ansible-playbook -i inventory/hosts.yml playbooks/kubernetes.yml

# Add new workers only
ansible-playbook -i inventory/hosts.yml playbooks/kubernetes.yml --limit <workers> --tags kubernetes,prerequisites,workers

# Install observability agents
ansible-playbook -i inventory/hosts.yml playbooks/observability.yml

# --- Terraform / OpenTofu (from terraform/) ---
./deploy.sh <host> init     # Initialize (golden-savanna, misty-bamboo, lush-forest)
./deploy.sh <host> plan     # Preview VM changes
./deploy.sh <host> apply    # Create/update VMs
./deploy.sh <host> destroy  # Destroy VMs

# --- Secrets ---
sops <file>.yaml            # Edit encrypted file
sops -d <file>.yaml         # Decrypt to stdout
./bootstrap/scripts/decrypt-key.sh  # Decrypt SSH deploy key
```

## Architecture

### Network Flow
Internet → Cloudflare Tunnel → Traefik (Ingress) → K8s Services

### Connectivity
- **Tailscale**: All hosts/VMs addressable by hostname (no hardcoded IPs)
- **K8s CNI**: Flannel with `--iface=tailscale0` (pod network 10.244.0.0/16)

### GitOps Flow
1. Edit manifests in `kubernetes/` directory
2. Commit and push to git
3. FluxCD auto-reconciles (or force with `flux reconcile`)

### Adding New Apps
1. Create manifests in `kubernetes/apps/<app-name>/`
2. Add to `kubernetes/apps/kustomization.yaml`
3. Commit, push, and Flux deploys automatically

### Adding New Hosts/Workers
1. Bootstrap bare metal: `ansible-playbook ... playbooks/bootstrap.yml`
2. Configure hypervisor: `ansible-playbook ... playbooks/site.yml --tags hypervisor`
3. Provision VMs: `./deploy.sh <host> apply`
4. Join K8s: `ansible-playbook ... playbooks/kubernetes.yml --limit <workers>`
5. Update Prometheus targets in `kubernetes/infrastructure/observability/`

## Key Files

- `bootstrap/ansible/inventory/hosts.yml` - Production host inventory
- `kubernetes/infrastructure/kustomization.yaml` - Infrastructure components
- `kubernetes/apps/kustomization.yaml` - Application deployments
- `terraform/hosts/<hostname>/` - Per-host VM definitions
- `secrets/` - SOPS-encrypted secrets (age key at `~/.config/sops/age/keys.txt`)
