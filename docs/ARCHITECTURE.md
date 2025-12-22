# Azalea v6 - Home Lab Architecture Spec

> Living document - update as we build

## Overview

Scalable, hardened home lab. Starts with 1 node, grows organically. Full Kubernetes for learning, GitOps-native, hybrid-cloud ready.

---

## Confirmed Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Base OS | **Ubuntu Server 24.04** | Simple, well-documented, familiar |
| Orchestration | **Full Kubernetes (kubeadm)** | Production-like experience, learning value |
| Virtualization | **Bare-metal K8s** | Maximum efficiency, add VMs later if needed |
| GitOps | **FluxCD** | Lightweight, native Helm/Kustomize |
| Ingress | **Traefik** | Flexible, K8s-native, good ecosystem |
| External Access | **Cloudflare Tunnel** | Already set up, zero-trust |
| Mesh Network | **Tailscale** | Easy node connectivity, subnet routing |
| Secrets | **SOPS + age** | Git-friendly encryption |

---

## Hardware

| Hostname | Specs | Storage | Role |
|----------|-------|---------|------|
| `golden-savanna` | 6c/12t, 32GB | 512GB SSD | Primary (control + workloads) |
| `misty-bamboo` | 4c/8t, 32GB | 256GB SSD | Worker (scale-up) |
| `lush-rainforest` | 4c/8t, 32GB | 256GB SSD | Worker (scale-up) |
| `wild-outback` | 16c/32t, 128GB | Variable | Burst (your machine, occasional) |

**Single-node mode**: Control plane runs workloads (untainted). Scale by adding workers.

---

## Naming Convention

**Theme**: Zoo (Habitats → Animals)

```
┌─────────────────────────────────────────────────────────────────┐
│  🦁 Naming Convention                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  BARE METAL (Habitats):                                         │
│  ──────────────────────                                         │
│    golden-savanna      primary, largest                         │
│    misty-bamboo        secondary                                │
│    lush-rainforest     tertiary                                 │
│    wild-outback        burst machine (temporary)                │
│                                                                  │
│  VMs (Animals) - use as needed:                                 │
│  ──────────────────────────────                                 │
│    sleepy-koala        chill, stable workloads                 │
│    lazy-panda          dev environment                         │
│    chunky-wombat       heavy compute                           │
│    fancy-penguin       k8s dev/testing                         │
│                                                                  │
│  Reserved for future:                                           │
│    curious-otter       experiments                              │
│    wise-owl            monitoring                               │
│    swift-fox           quick tasks                              │
│                                                                  │
│  K8s NAMESPACES (Zoo sections):                                 │
│  ──────────────────────────────                                 │
│    sanctuary           production (protected)                   │
│    petting-zoo         dev/test (safe to touch)                │
│    aquatic             water-related/databases                  │
│    nocturnal           background jobs, monitoring              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Examples**:
```bash
$ ssh golden-savanna           # bare metal
$ ssh sleepy-koala             # VM
$ kubectl config use-context golden-savanna
$ kubectl get pods -n sanctuary
```

---

## Resource Allocation (VMs When Added)

### Bare-Metal K8s (Current Plan)

No VMs initially - K8s runs directly on hardware for efficiency.

**Resource reservations**:
```
┌─────────────────────────────────────────────────────────────────┐
│  node-1 (6c/12t, 32GB)              │  Available for K8s       │
│  ─────────────────────              │  ─────────────────       │
│  OS + system: 2GB RAM, 2 threads    │  30GB RAM, 10 threads    │
│  kubelet reserved: 1GB              │                          │
├─────────────────────────────────────┼──────────────────────────┤
│  node-2 (4c/8t, 32GB)               │  Available for K8s       │
│  ─────────────────────              │  ─────────────────       │
│  OS + system: 2GB RAM, 1 thread     │  29GB RAM, 7 threads     │
│  kubelet reserved: 1GB              │                          │
├─────────────────────────────────────┼──────────────────────────┤
│  node-3 (4c/8t, 32GB)               │  Available for K8s       │
│  ─────────────────────              │  ─────────────────       │
│  OS + system: 2GB RAM, 1 thread     │  29GB RAM, 7 threads     │
│  kubelet reserved: 1GB              │                          │
└─────────────────────────────────────┴──────────────────────────┘

Total K8s capacity: ~88GB RAM, 24 threads
Single-node (node-1 only): 30GB RAM, 10 threads
```

### If Adding VMs Later (Virtualization Layer)

Use case: Dev K8s cluster, Windows VM, isolated testing

**Option A: VMs on node-1 only** (keep node-2/3 for prod K8s)
```
┌─────────────────────────────────────────────────────────────────┐
│  node-1 (6c/12t, 32GB) - Hypervisor + VMs                       │
├─────────────────────────────────────────────────────────────────┤
│  Host OS:        2GB RAM,  2 threads                            │
│  libvirt/QEMU:   1GB RAM,  0 threads (shared)                   │
│  ─────────────────────────────────────────────────────────────  │
│  VM: dev-k8s     8GB RAM,  4 threads  (dev cluster)             │
│  VM: windows    12GB RAM,  4 threads  (if needed)               │
│  VM: sandbox     4GB RAM,  2 threads  (testing)                 │
│  ─────────────────────────────────────────────────────────────  │
│  Reserved:       5GB RAM              (buffer)                  │
└─────────────────────────────────────────────────────────────────┘
```

**Option B: Distributed VMs** (VMs across nodes)
```
┌──────────────────┬──────────────────┬──────────────────┐
│ node-1 (32GB)    │ node-2 (32GB)    │ node-3 (32GB)    │
├──────────────────┼──────────────────┼──────────────────┤
│ Host: 3GB        │ Host: 3GB        │ Host: 3GB        │
│ K8s ctrl: 8GB    │ K8s work: 12GB   │ K8s work: 12GB   │
│ VM-dev: 8GB      │ VM-test: 8GB     │ (no VMs)         │
│ Buffer: 13GB     │ Buffer: 9GB      │ Buffer: 17GB     │
└──────────────────┴──────────────────┴──────────────────┘
```

### VM Sizing Guidelines

| VM Type | Min RAM | Recommended | vCPUs | Disk |
|---------|---------|-------------|-------|------|
| K8s single-node (dev) | 4GB | 8GB | 2-4 | 40GB |
| K8s worker | 4GB | 8GB | 2-4 | 40GB |
| Windows 11 | 8GB | 16GB | 4 | 80GB |
| Ubuntu desktop | 4GB | 8GB | 2-4 | 40GB |
| Minimal server | 1GB | 2GB | 1-2 | 20GB |
| Container test | 2GB | 4GB | 2 | 20GB |

### Overcommit Strategy

**CPU**: Safe to overcommit 2:1 (24 vCPUs on 12 threads)
- VMs rarely use 100% CPU continuously
- K8s has CPU limits/requests

**RAM**: Don't overcommit
- Linux OOM killer will cause problems
- Always leave 10-15% buffer
- Use K8s memory limits strictly

### Cloud Burst Node (Your Machine)

When adding your 16c/32t, 128GB machine temporarily:
```
┌─────────────────────────────────────────────────────────────────┐
│  burst-node (16c/32t, 128GB) - Temporary capacity               │
├─────────────────────────────────────────────────────────────────┤
│  Join as K8s worker: ~120GB RAM, 30 threads available          │
│  Or run VMs: 8-10 VMs comfortably                               │
│  Use: Heavy builds, ML training, batch processing               │
│                                                                  │
│  Workflow:                                                       │
│  1. Install Tailscale → joins mesh automatically                │
│  2. Run kubeadm join → becomes K8s worker                       │
│  3. Taint node: burst=true:PreferNoSchedule                     │
│  4. Workloads opt-in with tolerations                           │
│  5. When done: kubectl drain → power off                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Storage Strategy

**Current Hardware**: 2x 512GB SSD + 1x 256GB SSD (~1.25TB total, no HDDs)

```
┌─────────────────────────────────────────────────────────┐
│                Storage Allocation                        │
├─────────────────────────────────────────────────────────┤
│  node-1 (512GB SSD)    │  node-2 (512GB)  │  node-3 (256GB) │
│  ──────────────────    │  ─────────────   │  ────────────── │
│  • OS: ~30GB           │  • OS: ~30GB     │  • OS: ~30GB    │
│  • K8s: ~50GB          │  • K8s: ~50GB    │  • K8s: ~30GB   │
│  • Apps: ~350GB        │  • Apps: ~350GB  │  • Apps: ~150GB │
│  • Reserved: ~80GB     │  • Reserved: 80GB│  • Reserved: 45GB│
└─────────────────────────────────────────────────────────┘
```

**Storage Classes**:
- `local-path` (default): Fast SSD, single-node, no replication
- `longhorn` (Phase 5): Replicated across nodes when multi-node
- `nfs-share` (optional): Share storage between nodes if needed

**Media Strategy** (Jellyfin):
- Option A: USB external drive on primary node (cheap, easy)
- Option B: Stream from cloud (Plex Cloud, etc.)
- Option C: Add HDD later when found at Goodwill
- Start small - don't need media server day 1

---

## Network Architecture

**Current Constraints**: No VLANs, no managed switch (flat network)
**Design Goal**: Zero hardcoded IPs, reproducible, uniform across all nodes/VMs

### Network Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                        LAYER 1: Physical/LAN                     │
│  Your router hands out DHCP - we don't care about these IPs     │
│  192.168.x.x (whatever your router assigns)                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     LAYER 2: Tailscale Overlay                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ node-1   │  │ node-2   │  │ node-3   │  │ vm-dev-1 │        │
│  │ 100.x.x.a│  │ 100.x.x.b│  │ 100.x.x.c│  │ 100.x.x.d│        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│       │              │              │              │            │
│       └──────────────┴──────────────┴──────────────┘            │
│                    WireGuard mesh (automatic)                    │
│                                                                  │
│  • Auto-assigned IPs (no config needed)                         │
│  • Addressable by hostname: node-1, node-2, vm-dev-1            │
│  • Works across LAN, internet, cloud - anywhere                 │
│  • MagicDNS: node-1.tailnet-name.ts.net                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     LAYER 3: Kubernetes CNI                      │
│  Handled by Cilium (recommended) or Calico                      │
│                                                                  │
│  Pod network:     10.244.0.0/16 (auto-assigned to pods)         │
│  Service network: 10.96.0.0/12  (auto-assigned to services)     │
│                                                                  │
│  • Pods get IPs automatically from CNI                          │
│  • Services get ClusterIPs automatically                        │
│  • No manual IP assignment ever                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     LAYER 4: Ingress                             │
│  Traefik routes external traffic to services                    │
│                                                                  │
│  Internet → Cloudflare Tunnel → Traefik → K8s Service → Pod    │
└─────────────────────────────────────────────────────────────────┘
```

### Why Tailscale (No VXLAN Needed)

| Feature | VXLAN | Tailscale |
|---------|-------|-----------|
| Setup complexity | High (need to configure on each host) | Low (install + auth) |
| IP assignment | Manual or need DHCP | Automatic |
| Cross-internet | No (L2 only) | Yes (works everywhere) |
| Encryption | No (need IPsec on top) | Built-in (WireGuard) |
| VM support | Yes | Yes (install in VM) |
| Cloud burst | Complex | Just install Tailscale |
| Reproducibility | Need IP planning | Zero config |

**VXLAN is overkill** for your setup. It's for:
- Data centers needing L2 across L3
- Multi-tenant isolation
- Thousands of hosts

**Tailscale gives you**:
- Zero IP management
- Works on physical nodes, VMs, containers, cloud
- Hostname-based addressing (no IPs in configs)
- Built-in DNS (MagicDNS)
- ACLs for security

### How VMs Connect (When Added)

```
┌─────────────────────────────────────────────────────────────────┐
│  Physical Host (node-1)                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Tailscale (100.x.x.1)                                   │   │
│  │       │                                                   │   │
│  │  ┌────┴────┐                                             │   │
│  │  │ libvirt │                                             │   │
│  │  │ bridge  │ (virbr0 - NAT, internal only)              │   │
│  │  └────┬────┘                                             │   │
│  │       │                                                   │   │
│  │  ┌────┴────────────┬─────────────────┐                   │   │
│  │  ▼                 ▼                 ▼                   │   │
│  │ ┌─────────┐    ┌─────────┐    ┌─────────┐               │   │
│  │ │  VM 1   │    │  VM 2   │    │  VM 3   │               │   │
│  │ │Tailscale│    │Tailscale│    │Tailscale│               │   │
│  │ │100.x.x.5│    │100.x.x.6│    │100.x.x.7│               │   │
│  │ └─────────┘    └─────────┘    └─────────┘               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

VM networking:
1. VM gets NAT IP from libvirt (192.168.122.x) - don't care about this
2. VM installs Tailscale → gets 100.x.x.x automatically
3. VM is now addressable as vm-1.tailnet.ts.net from anywhere
4. No port forwarding, no bridge config, no IP planning
```

### Reproducibility: Zero Hardcoded IPs

**Ansible inventory uses hostnames, not IPs**:
```yaml
# inventory/hosts.yml
all:
  children:
    k8s_nodes:
      hosts:
        node-1:  # Tailscale resolves this
        node-2:
        node-3:
    vms:
      hosts:
        vm-dev-1:
        vm-test-1:
```

**K8s configs use DNS names**:
```yaml
# No IPs anywhere - use service names
apiVersion: v1
kind: Service
metadata:
  name: my-app
# Access as: my-app.namespace.svc.cluster.local
```

**Tailscale provides**:
- `node-1` → resolves to 100.x.x.a (auto)
- `vm-dev-1` → resolves to 100.x.x.d (auto)
- No /etc/hosts, no DNS records to manage

### CNI Choice: Cilium (Recommended)

| Feature | Calico | Cilium |
|---------|--------|--------|
| Performance | Good | Better (eBPF) |
| NetworkPolicy | Yes | Yes + more features |
| Observability | Basic | Hubble (excellent) |
| Service mesh | No | Built-in (optional) |
| Complexity | Lower | Slightly higher |
| Resource usage | Lower | ~100MB more RAM |

**Recommendation**: Cilium
- Better visibility into network traffic
- eBPF = faster networking
- Can replace kube-proxy
- Hubble UI for debugging

### Network Security (No VLANs)

Without VLANs, we use software-defined security:

```
┌──────────────────────────────────────────────────────────┐
│                    Security Layers                        │
├──────────────────────────────────────────────────────────┤
│ 1. Tailscale ACLs     │ Who can talk to whom             │
│                       │ (defined in Tailscale admin)      │
├───────────────────────┼──────────────────────────────────┤
│ 2. UFW on hosts       │ Block non-Tailscale traffic      │
│                       │ Only allow: 22, 6443 via TS      │
├───────────────────────┼──────────────────────────────────┤
│ 3. K8s NetworkPolicy  │ Pod-to-pod isolation             │
│    (via Cilium)       │ Namespace isolation              │
├───────────────────────┼──────────────────────────────────┤
│ 4. Cloudflare WAF     │ Public endpoint protection       │
└───────────────────────┴──────────────────────────────────┘
```

### When You Get a Switch (Future)

Adding VLANs later is easy - nothing changes in K8s/Tailscale:
1. Assign VLAN to switch ports
2. Nodes get IPs from VLAN DHCP
3. Tailscale still works (it doesn't care about underlying IPs)
4. K8s still works (CNI doesn't care)
5. Only change: maybe tighter firewall rules on VLAN level

---

## Services to Deploy

| Priority | Service | Exposed | Notes |
|----------|---------|---------|-------|
| P0 | AdGuard Home | No | DNS first, everything depends on it |
| P0 | Traefik | Yes | Ingress controller |
| P1 | Cloudflare Tunnel | Yes | Connect to internet |
| P1 | Home Assistant | Yes | Smart home |
| P2 | Jellyfin | Yes | Media server (needs HDD storage) |
| P2 | Calibre-web | Yes | Books |
| P3 | Monitoring stack | No | Prometheus/Grafana or lighter |
| P3 | Authelia | Yes | SSO for all exposed services |

---

## Security Layers

1. **Node**: SSH keys only, fail2ban, unattended-upgrades, UFW
2. **Network**: Tailscale ACLs, Cloudflare WAF
3. **Cluster**: NetworkPolicies, PodSecurity standards
4. **Apps**: Authelia SSO, per-app auth where needed
5. **Secrets**: SOPS-encrypted in Git, never plain text

---

## Backup Strategy

**Philosophy**: Free first, then cheap, automate everything

**Tool**: Restic (deduplication, encryption, multiple backends)

**Backup Tiers**:
```
┌─────────────────────────────────────────────────────────┐
│                    Backup Tiers                          │
├─────────────────────────────────────────────────────────┤
│  Tier 1: Local         │  Tier 2: Offsite (Free)        │
│  ─────────────         │  ─────────────────────         │
│  • Cross-node rsync    │  • Cloudflare R2 (10GB free)   │
│  • Quick recovery      │  • Oracle Cloud (10GB free)    │
│  • No egress cost      │  • Or: rsync to burst machine  │
└─────────────────────────────────────────────────────────┘
```

**What to Backup**:
| Priority | Data | Method | Frequency |
|----------|------|--------|-----------|
| Critical | K8s etcd snapshots | Restic → R2 | Daily |
| Critical | SOPS secrets | Git (encrypted) | On change |
| High | App configs | Git + Restic | Daily |
| High | Home Assistant DB | Restic → R2 | Daily |
| Medium | Persistent volumes | Restic → local | Weekly |
| Low | Logs, metrics | Don't backup | - |

**Free Tier Breakdown**:
- Cloudflare R2: 10GB storage, free egress (best for restore)
- Oracle Cloud: 10GB object + 200GB block (generous)
- Backblaze B2: 10GB free (cheap beyond: $0.005/GB)

**Recommendation**: Start with R2 (you have Cloudflare), add Oracle for redundancy

---

## Project Structure

```
azalea-v6/
├── flake.nix                     # Dev environment (kubectl, flux, sops, etc.)
├── CLAUDE.md                     # AI context file
├── docs/
│   └── ARCHITECTURE.md           # This spec (copy from plan)
│
├── bootstrap/                    # One-time node setup
│   ├── ansible/
│   │   ├── inventory/
│   │   │   └── hosts.yml
│   │   ├── playbooks/
│   │   │   └── site.yml          # Main playbook
│   │   └── roles/
│   │       ├── common/           # Base packages, users, SSH
│   │       ├── kubernetes/       # kubeadm setup
│   │       └── storage/          # Disk mounts, NFS
│   └── scripts/
│       └── init-cluster.sh       # kubeadm init wrapper
│
├── kubernetes/
│   ├── clusters/
│   │   └── homelab/
│   │       ├── flux-system/      # FluxCD bootstrap (auto-generated)
│   │       └── cluster-config.yaml
│   │
│   ├── infrastructure/           # Cluster-wide infrastructure
│   │   ├── sources/              # Helm repos, OCI sources
│   │   ├── controllers/
│   │   │   ├── traefik/
│   │   │   ├── cert-manager/
│   │   │   └── cloudflared/
│   │   ├── networking/
│   │   │   ├── network-policies/
│   │   │   └── tailscale/
│   │   ├── storage/
│   │   │   ├── local-path/
│   │   │   └── longhorn/         # Enable when multi-node
│   │   ├── security/
│   │   │   └── authelia/
│   │   └── observability/
│   │       ├── prometheus/
│   │       └── grafana/
│   │
│   └── apps/                     # User applications
│       ├── _template/            # Copy for new apps
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── deployment.yaml
│       │   └── ingress.yaml
│       ├── adguard-home/
│       ├── home-assistant/
│       ├── jellyfin/
│       └── calibre-web/
│
├── terraform/                    # Cloud resources only
│   └── cloudflare/
│       ├── main.tf
│       ├── tunnel.tf
│       └── dns.tf
│
└── secrets/                      # SOPS-encrypted
    ├── .sops.yaml                # SOPS config
    └── cluster-secrets.yaml      # Encrypted secrets
```

---

## Implementation Phases

### Phase 0: Foundation ◄── CURRENT
- [ ] Create project structure
- [ ] Set up flake.nix with all tools
- [ ] Create CLAUDE.md for AI context
- [ ] Copy architecture spec to docs/

### Phase 1: Single Node Bootstrap
- [ ] Ansible role: common (users, SSH, packages)
- [ ] Ansible role: kubernetes (kubeadm, containerd)
- [ ] Ansible role: storage (mount HDDs, NFS server)
- [ ] Init script: kubeadm init + untaint control plane
- [ ] FluxCD bootstrap

### Phase 2: Core Infrastructure
- [ ] Traefik ingress controller
- [ ] cert-manager (Let's Encrypt via Cloudflare)
- [ ] local-path storage provisioner
- [ ] Cloudflare Tunnel deployment

### Phase 3: First Apps
- [ ] AdGuard Home (DNS)
- [ ] Home Assistant
- [ ] Basic monitoring (just metrics for now)

### Phase 4: More Apps + Hardening
- [ ] Calibre-web
- [ ] Authelia SSO
- [ ] NetworkPolicies for all apps
- [ ] Jellyfin (when HDD/USB storage available)

### Phase 5: Multi-Node (Future)
- [ ] Ansible: add worker playbook
- [ ] Longhorn storage
- [ ] Pod anti-affinity rules

### Phase 6: Hybrid Cloud (Future)
- [ ] Cloud node join procedure
- [ ] Cloud storage backends
- [ ] Cost controls

---

## Files to Create (Phase 0)

1. `flake.nix` - Dev environment with:
   - kubectl, kubeadm
   - flux CLI
   - sops, age
   - ansible, ansible-lint
   - terraform/opentofu
   - k9s, helm
   - jq, yq

2. `CLAUDE.md` - AI context with:
   - Project overview
   - Directory structure explanation
   - Current phase and status
   - Key commands

3. `docs/ARCHITECTURE.md` - This spec

4. Directory structure with placeholder READMEs

---

## Resolved Questions

| Question | Answer | Impact |
|----------|--------|--------|
| Storage | SSDs only (512+512+256GB), no HDDs | Adjusted storage tiers, media deferred |
| Network | No VLANs, no switch | Flat network + NetworkPolicies, future-ready |
| Backup | Free first (R2, Oracle) | Restic + R2 strategy defined |
| Media (Jellyfin) | Deferred until HDD/USB available | Lower priority in phases |

---

## Ready to Execute

Phase 0 deliverables:
1. Create directory structure (as outlined above)
2. Write `flake.nix` with all dev tools
3. Write `CLAUDE.md` for AI context
4. Copy this spec to `docs/ARCHITECTURE.md`

Approve to proceed with implementation.
