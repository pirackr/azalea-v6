# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Azalea v6 is a home lab Kubernetes infrastructure project with VMs on bare metal hosts. Uses GitOps (FluxCD) for declarative cluster management.

## Hardware

| Hostname | Specs | Role |
|----------|-------|------|
| `golden-savanna` | 6c/12t, 32GB, 512GB SSD | Primary (control + workloads) |
| `misty-bamboo` | 4c/8t, 32GB, 256GB SSD | Worker |
| `lush-forest` | 4c/8t, 32GB, 256GB SSD | Worker |

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

**Theme**: Zoo - Bare metal hosts = Habitats, VMs = Animals

## Tech Stack

| Layer | Technology |
|-------|------------|
| Base OS | Ubuntu Server 24.04 |
| Virtualization | KVM/libvirt |
| Orchestration | Kubernetes (kubeadm) |
| CNI | Flannel over Tailscale |
| GitOps | FluxCD |
| Ingress | Traefik |
| External Access | Cloudflare Tunnel |
| Mesh Network | Tailscale |
| Secrets | Doppler (infra), SOPS + age (K8s) |
| IaC | OpenTofu, Ansible |
| Cloudflare | Tunnel, R2 (TF state) |

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

# --- Flux Troubleshooting ---
flux logs --follow                         # Stream Flux logs
kubectl logs -n flux-system deploy/source-controller
kubectl logs -n flux-system deploy/kustomize-controller
kubectl describe helmrelease -n <namespace> <release-name>

# --- Ansible (use run.sh wrapper - injects secrets from Doppler) ---
# Bootstrap new bare metal host (first time, with password)
./bootstrap/ansible/run.sh playbooks/bootstrap.yml -i inventory/bootstrap.yml -u <user> -kK

# Configure hypervisor
./bootstrap/ansible/run.sh playbooks/site.yml -i inventory/hosts.yml --limit <host> --tags hypervisor

# Deploy/update K8s cluster
./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml

# Add new workers only
./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml --limit <workers> --tags kubernetes,prerequisites,workers

# Install observability agents
./bootstrap/ansible/run.sh playbooks/observability.yml -i inventory/hosts.yml

# --- Terraform / OpenTofu (use deploy.sh wrapper - injects secrets from Doppler) ---
# VM management (golden-savanna, misty-bamboo, lush-forest)
./terraform/deploy.sh <host> init
./terraform/deploy.sh <host> plan
./terraform/deploy.sh <host> apply
./terraform/deploy.sh <host> destroy

# Cloudflare resources (tunnel, DNS)
./terraform/deploy.sh cloudflare init
./terraform/deploy.sh cloudflare plan
./terraform/deploy.sh cloudflare apply

# --- Secrets ---
# Infrastructure secrets: Doppler (project: azalea, config: main)
doppler secrets                       # List all secrets
doppler secrets set KEY=value         # Set a secret

# K8s secrets: SOPS + age (encrypted in git)
sops <file>.yaml                      # Edit encrypted file
sops -d <file>.yaml                   # Decrypt to stdout
```

## Architecture

### Network Flow
Internet → Cloudflare Tunnel → Traefik (Ingress) → K8s Services

### Connectivity
- **Tailscale**: All hosts/VMs addressable by hostname (no hardcoded IPs in configs)
- **K8s CNI**: Flannel with `--iface=tailscale0` (pod network 10.244.0.0/16)

### GitOps Flow
1. Edit manifests in `kubernetes/` directory
2. Commit and push to git
3. FluxCD auto-reconciles (or force with `flux reconcile`)

### Adding New Apps
1. Create manifests in `kubernetes/apps/<app-name>/` (copy from `_template/`)
2. Add to `kubernetes/apps/kustomization.yaml`
3. Commit, push, and Flux deploys automatically

### Adding New Hosts/Workers
1. Bootstrap bare metal: `./bootstrap/ansible/run.sh playbooks/bootstrap.yml -i inventory/bootstrap.yml -u <user> -kK`
2. Configure hypervisor: `./bootstrap/ansible/run.sh playbooks/site.yml -i inventory/hosts.yml --limit <host> --tags hypervisor`
3. Provision VMs: `./terraform/deploy.sh <host> apply`
4. Join K8s: `./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml --limit <workers>`
5. Update Prometheus targets in `kubernetes/infrastructure/observability/`

## Style Guidelines

- Use 2-space indentation in YAML and Terraform
- Commit messages follow Conventional Commits (`fix(observability): ...`, `feat(apps): ...`)
- Infrastructure secrets go in Doppler; K8s secrets use SOPS encryption
- Prefer hostnames over IPs in inventories and manifests

## Key Files

- `bootstrap/ansible/run.sh` - Ansible wrapper (injects Doppler secrets)
- `bootstrap/ansible/inventory/hosts.yml` - Production host inventory
- `terraform/deploy.sh` - OpenTofu wrapper (injects Doppler secrets)
- `terraform/hosts/<hostname>/` - Per-host VM definitions
- `terraform/cloudflare/` - Cloudflare tunnel and DNS management
- `kubernetes/infrastructure/kustomization.yaml` - Infrastructure components
- `kubernetes/apps/kustomization.yaml` - Application deployments
- `secrets/deploy_key.pub` - SSH public key (only public key remains in git)
