# Azalea v6 - AI Context

> This file provides context for AI assistants working on this project.

## Project Overview

Azalea v6 is a home lab infrastructure project designed for:
- Self-hosting applications (Home Assistant, Jellyfin, AdGuard Home, etc.)
- Learning Kubernetes and infrastructure as code
- Scalable from 1 node to multi-node cluster
- Hybrid-ready (can burst to cloud)

## Current Phase

**Phase 0: Foundation** (COMPLETE)
- [x] Project structure created
- [x] flake.nix with dev tools
- [x] CLAUDE.md (this file)
- [x] Architecture documentation

**Next: Phase 1 - Single Node Bootstrap**

## Hardware

| Hostname | Specs | Role |
|----------|-------|------|
| `golden-savanna` | 6c/12t, 32GB, 512GB SSD | Primary (control + workloads) |
| `misty-bamboo` | 4c/8t, 32GB, 256GB SSD | Worker (scale-up) |
| `lush-rainforest` | 4c/8t, 32GB, 256GB SSD | Worker (scale-up) |
| `wild-outback` | 16c/32t, 128GB | Burst (temporary) |

## Naming Convention

**Theme**: Zoo (Habitats contain Animals)

- **Bare metal** = Habitats: `golden-savanna`, `misty-bamboo`, `lush-rainforest`
- **VMs** = Animals: `sleepy-koala`, `lazy-panda`, `chunky-wombat`, `fancy-penguin`
- **K8s namespaces** = Zoo sections: `sanctuary`, `petting-zoo`, `aquatic`, `nocturnal`

## Tech Stack

| Layer | Technology |
|-------|------------|
| Base OS | Ubuntu Server 24.04 |
| Orchestration | Kubernetes (kubeadm) |
| CNI | Cilium |
| GitOps | FluxCD |
| Ingress | Traefik |
| External Access | Cloudflare Tunnel |
| Mesh Network | Tailscale |
| Secrets | SOPS + age |

## Directory Structure

```
azalea-v6/
├── flake.nix                 # Nix dev environment
├── CLAUDE.md                 # This file (AI context)
├── docs/
│   └── ARCHITECTURE.md       # Full architecture spec
│
├── bootstrap/                # One-time node setup
│   ├── ansible/              # Ansible playbooks & roles
│   │   ├── inventory/        # Host definitions
│   │   ├── playbooks/        # Main playbooks
│   │   └── roles/            # Reusable roles
│   └── scripts/              # Shell scripts
│
├── kubernetes/
│   ├── clusters/homelab/     # Cluster-specific config
│   ├── infrastructure/       # Cluster-wide infra
│   │   ├── controllers/      # Ingress, certs, etc.
│   │   ├── networking/       # Network policies
│   │   ├── storage/          # Storage classes
│   │   └── observability/    # Monitoring
│   └── apps/                 # User applications
│
├── terraform/cloudflare/     # Cloud resources
└── secrets/                  # SOPS-encrypted secrets
```

## Key Commands

```bash
# Enter dev environment
nix develop

# Kubernetes
kubectl get pods -A
k9s
flux check

# Ansible
cd bootstrap/ansible
ansible-playbook playbooks/site.yml

# Secrets
sops secrets/cluster-secrets.yaml
```

## Design Principles

1. **Start Small**: Everything works on 1 node
2. **Scale Gracefully**: Add nodes without reconfiguration
3. **Loosely Coupled**: Each component independent
4. **Hardened by Default**: Security not an afterthought
5. **GitOps Native**: All state in Git, declarative
6. **Zero Hardcoded IPs**: Use hostnames via Tailscale
7. **Hybrid-Ready**: Can burst to cloud when needed

## Network Architecture

- **Physical**: DHCP from router (we don't care about these IPs)
- **Tailscale**: Auto-assigned 100.x.x.x, hostname-addressable
- **K8s CNI**: Cilium handles pod networking (10.244.0.0/16)
- **Ingress**: Internet → Cloudflare Tunnel → Traefik → Services

## Important Notes

- No VLANs currently (flat network)
- Pure Tailscale for node/VM connectivity
- SSDs only (~1.25TB total), no HDDs yet
- Jellyfin deferred until storage available

## References

- Full spec: `docs/ARCHITECTURE.md`
- Plan file: `~/.claude/plans/cryptic-sauteeing-rose.md`
