# Azalea Dev Pod Questionnaire

Please answer the questions below so I can draft the Kubernetes manifests and
security configuration for the azalea-dev pod.

## 1) Target cluster + namespace
- Which cluster/context should this be deployed to?
> Current k8s cluster?

- Preferred namespace name?
> dev

## 2) Image + OS baseline
- Preferred base image/OS (Debian, Ubuntu, Alpine, NixOS, other)?
> debian 
- Any required distro versions or constraints?
> no 

## 3) Access model (SSH)
- How should SSH be exposed? (ClusterIP + port-forward, NodePort, LoadBalancer, Ingress, none)
> should be exposed through Cloudflared

- Any existing SSH port preferences?
> no

- Desired username inside the pod?
> pirackr

## 4) Authentication + SSH hardening
-  Provide your authorized public keys (paste or file path).
 > ~/.ssh/id_ed25519_sk_yk1.pub
 > ~/.ssh/id_ed25519_sk_yk2.pub
- Confirm: disable password authentication?
 > yes  
- Any additional SSH restrictions (allowlist IPs, `AllowUsers`, `AllowGroups`)?
 > No
## 5) AI tools
- Which exact CLI tools do you want installed?
  - Claude (anthropic/claude-cli?)
  > Yes
  - Codex (OpenAI Codex CLI?)
  > Yes
  - OpenCode (opencode CLI?)
  > Yes
- How should API keys/tokens be provided? (SOPS secret, sealed secret, Doppler, manual)
  > Manual 
## 6) Git + Nix
- Do you want nix installed inside the pod, or mounted from host?
 > inside pod
- Any specific git configuration or credentials handling?
 > No

## 7) YubiKey support
- What YubiKey features do you need? (gpg-agent, ssh-agent, FIDO2/WebAuthn, PIV)
 > Don't know, enough for me to use yubikey with ssh and git?
- How will the YubiKey be connected? (USB passthrough to node, remote agent, none)
 > USB passthrough to node?
- If using GPG/SSH agent forwarding, any existing setup to integrate?
  > No
- Clarify: use `ssh-agent` with FIDO2 keys only, or also GPG/PIV?
> FIDO2 only. Can I use the FIDO key from my host in that server?

## 8) Storage
- Should the workspace be persistent? (PVC) If yes, size and storage class?
 > Yes
- Any additional volumes needed?
 > May be a single one ~20GB is enough I guess?
  > Good enough?
- Confirm PVC size (e.g., 20Gi) and storage class name.
> 20Gi is good enough. Storage class: longhorn.

## 9) Resources + scheduling
- CPU/memory requests/limits?
 > Just for development so guess it's just enough? 
- Any node selectors/taints/tolerations/affinity needed?
 > no
- OK to set defaults like requests `500m/1Gi` and limits `2CPU/4Gi`?
> OK.

## 10) Security + policy
- Should this run as non-root? (recommended)
 > Do we need root for something? this is just for development
- Any PodSecurity/NetworkPolicy requirements?
 > no 
- OK to run as non-root and only use root at image build time?
> OK, but what are the differences?

## 11) Bootstrapping
- Should I bake tools into a custom image or use a stock image with init scripts?
 > custom image? 
- If custom image, where should the Dockerfile live?
 > I'm thinking, should we use github for it? 
- Should the image be built/pushed to GHCR from this repo?
> Put it here first. Also create GitHub Actions to publish it.
- What image name/tag scheme do you want?
> Good enough.

## 12) Kubeconfig
- You mentioned Doppler provides `KUBECONFIG`. Confirm: mount it to `/home/pirackr/.kube/config` by default?
> yes 
