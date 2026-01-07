# Azalea v6

Home lab infrastructure - Kubernetes on bare metal with VMs.

## Architecture

**Bare Metal Hosts (Habitats):**
| Host | Specs | Role |
|------|-------|------|
| `golden-savanna` | 6c/12t, 32GB, 512GB | Primary hypervisor |
| `misty-bamboo` | 4c/8t, 32GB, 256GB | Secondary hypervisor |
| `lush-forest` | 4c/8t, 32GB, 256GB | Secondary hypervisor |

**K8s VMs (Animals):**
| VM | RAM | vCPU | Disk | Role | Host |
|----|-----|------|------|------|------|
| `sleepy-koala` | 8GB | 4 | 80GB | K8s control-plane | golden-savanna |
| `lazy-panda` | 20GB | 8 | 200GB | K8s worker | golden-savanna |
| `chunky-wombat` | 14GB | 4 | 100GB | K8s worker | misty-bamboo |
| `fancy-penguin` | 14GB | 4 | 100GB | K8s worker | misty-bamboo |
| `grumpy-walrus` | 14GB | 4 | 70GB | K8s worker | lush-forest |
| `happy-dolphin` | 14GB | 4 | 70GB | K8s worker | lush-forest |

## Complete Setup Guide

### Prerequisites

1. **Bare metal hosts** running Ubuntu 24.04
2. **Nix** package manager installed
3. **Network access** to all hosts
4. **SOPS + age** keys for secrets (see `secrets/README.md`)

### Step 1: Bootstrap Bare Metal Hosts

Bootstrap sets up SSH keys, Tailscale, and the deploy user on each bare metal host.

```bash
# Enter dev environment
nix develop

# Bootstrap a new bare metal host (first time only)
# Update IP in bootstrap/ansible/inventory/bootstrap.yml first
# Use run.sh wrapper - it injects secrets from Doppler automatically
./bootstrap/ansible/run.sh playbooks/bootstrap.yml \
  -i inventory/bootstrap.yml --limit <hostname> -u <initial-user> -kK

# Example: Bootstrap lush-forest
# ./bootstrap/ansible/run.sh playbooks/bootstrap.yml \
#   -i inventory/bootstrap.yml --limit lush-forest -u youruser -kK
```

### Step 2: Configure Hypervisor

Install KVM/libvirt and configure the hypervisor.

```bash
# Run hypervisor setup (uses Tailscale hostnames)
# Use run.sh wrapper - it injects secrets from Doppler automatically
./bootstrap/ansible/run.sh playbooks/site.yml \
  -i inventory/hosts.yml --limit <hostname> --tags hypervisor

# Example: Setup lush-forest hypervisor
# ./bootstrap/ansible/run.sh playbooks/site.yml \
#   -i inventory/hosts.yml --limit lush-forest --tags hypervisor
```

### Step 3: Provision VMs with Terraform

Create VMs using Terraform/OpenTofu.

```bash
# Use deploy.sh wrapper - it injects secrets from Doppler automatically
# Syntax: ./terraform/deploy.sh <host> <command>

# Initialize terraform for a host
./terraform/deploy.sh <hostname> init

# Review plan
./terraform/deploy.sh <hostname> plan

# Apply (creates VMs)
./terraform/deploy.sh <hostname> apply

# Example: Create VMs on lush-forest
# ./terraform/deploy.sh lush-forest init
# ./terraform/deploy.sh lush-forest plan
# ./terraform/deploy.sh lush-forest apply

# VMs will auto-start and join Tailscale network
```

### Step 4: Deploy Kubernetes Cluster

**Note:** Only needed for initial cluster setup or new worker nodes.

```bash
# For initial cluster setup (control plane + workers):
./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml

# For adding new worker nodes only:
./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml \
  --limit <new-worker-hostnames> --tags kubernetes,prerequisites,workers

# Example: Add grumpy-walrus and happy-dolphin
# ./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml \
#   --limit grumpy-walrus,happy-dolphin --tags kubernetes,prerequisites,workers
```

Verify cluster:
```bash
# Copy kubeconfig from control plane (first time only)
scp deploy@sleepy-koala:~/.kube/config ~/.kube/config-azalea

# Check nodes
export KUBECONFIG=~/.kube/config-azalea
kubectl get nodes
```

### Step 5: Install Observability Agents

Install node_exporter and promtail on all hosts and VMs.

```bash
# Install on all hosts and VMs
./bootstrap/ansible/run.sh playbooks/observability.yml -i inventory/hosts.yml

# Or target specific hosts
./bootstrap/ansible/run.sh playbooks/observability.yml -i inventory/hosts.yml \
  --limit <hostname1>,<hostname2>

# Example: Install on lush-forest and its VMs
# ./bootstrap/ansible/run.sh playbooks/observability.yml -i inventory/hosts.yml \
#   --limit lush-forest,grumpy-walrus,happy-dolphin
```

### Step 6: Update Prometheus Scrape Targets

After adding new hosts/VMs, update the Prometheus configuration:

```bash
# Edit kubernetes/infrastructure/observability/kube-prometheus-stack.yaml
# Add new hosts to additionalScrapeConfigs section

# Commit changes
git add kubernetes/infrastructure/observability/kube-prometheus-stack.yaml
git commit -m "feat(observability): add <hostname> to prometheus targets"
git push

# Flux will auto-reconcile, or force it:
flux reconcile kustomization infrastructure --with-source
```

### Step 7: Bootstrap External Secrets (First Time Only)

External Secrets Operator syncs secrets from Doppler to Kubernetes. The Doppler service token must be created manually as a bootstrap secret.

```bash
# Enter dev environment
nix develop

# Create a Doppler service token for External Secrets
doppler configs tokens create external-secrets --plain
# Save the token output (starts with dp.st.main.xxx)

# Create the namespace and bootstrap secret
export KUBECONFIG=~/.kube/config-azalea
kubectl create namespace external-secrets
kubectl create secret generic doppler-token \
  --namespace=external-secrets \
  --from-literal=token='<your-doppler-service-token>'

# Flux will deploy External Secrets Operator and ClusterSecretStore
flux reconcile kustomization infrastructure --with-source
```

## FluxCD Usage

FluxCD automatically syncs Kubernetes manifests from Git to the cluster.

### Basic Commands

```bash
# Check Flux system health
flux check

# View all Flux resources
flux get all

# View Kustomizations (deployments)
flux get kustomizations

# View HelmReleases
flux get helmreleases -A

# View Git sources
flux get sources git

# Force reconciliation (sync from Git now)
flux reconcile kustomization infrastructure --with-source
flux reconcile kustomization apps --with-source

# Force a specific HelmRelease to update
flux reconcile helmrelease -n <namespace> <release-name>
```

### Troubleshooting

```bash
# View Flux logs
kubectl logs -n flux-system deploy/source-controller
kubectl logs -n flux-system deploy/kustomize-controller
kubectl logs -n flux-system deploy/helm-controller

# Check HelmRelease status
kubectl describe helmrelease -n <namespace> <release-name>

# Suspend/resume reconciliation
flux suspend kustomization <name>
flux resume kustomization <name>
```

### Deploying New Apps

1. Create manifests in `kubernetes/apps/<app-name>/`
2. Add to `kubernetes/apps/kustomization.yaml`
3. Commit and push to git
4. Flux will auto-deploy within 10 minutes, or force:
   ```bash
   flux reconcile kustomization apps --with-source
   ```

## Quick Reference

```bash
# Kubernetes
kubectl get nodes                              # List all nodes
kubectl get pods -A                            # List all pods
kubectl get svc -A                             # List all services
kubectl logs -n <namespace> <pod>              # View pod logs
kubectl exec -it -n <namespace> <pod> -- bash  # Shell into pod

# Flux
flux get all                                   # View all Flux resources
flux reconcile kustomization apps              # Force sync apps from Git
flux logs --follow                             # Stream Flux logs

# Ansible (use run.sh wrapper - injects Doppler secrets)
./bootstrap/ansible/run.sh playbooks/site.yml -i inventory/hosts.yml           # Full setup
./bootstrap/ansible/run.sh playbooks/kubernetes.yml -i inventory/hosts.yml     # K8s setup
./bootstrap/ansible/run.sh playbooks/observability.yml -i inventory/hosts.yml  # Monitoring

# Terraform (use deploy.sh wrapper - injects Doppler secrets)
./terraform/deploy.sh <host> plan    # Preview changes
./terraform/deploy.sh <host> apply   # Create/update VMs
./terraform/deploy.sh <host> destroy # Destroy VMs

# Monitoring
curl http://<hostname>:9100/metrics  # Check node_exporter
tailscale status                     # View Tailscale network
```

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
- **CNI**: Flannel over Tailscale
- **GitOps**: FluxCD
- **Networking**: Tailscale
- **Secrets**: Doppler (infra) + External Secrets Operator (K8s)
- **IaC**: OpenTofu, Ansible
