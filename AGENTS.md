# Repository Guidelines

## Project Structure & Module Organization
- `bootstrap/ansible/` holds playbooks, roles, and inventories for host/VM setup.
- `kubernetes/` contains Flux-managed manifests, split into `infrastructure/`, `apps/`, and `clusters/`.
- `terraform/` defines per-host VM provisioning (OpenTofu/Terraform).
- `secrets/` stores SOPS-encrypted files; never commit plaintext secrets.
- `docs/` includes architecture references (`docs/ARCHITECTURE.md`).

## Build, Test, and Development Commands
- `nix develop` enters the dev shell with kubectl/flux/ansible/sops/tofu.
- For Flux/Kubernetes actions, use `nix develop --command` with `KUBECONFIG=$HOME/.kube/config-azalea` exported.
- `cd bootstrap/ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml` runs full host setup.
- `cd terraform/hosts/<hostname> && tofu plan` previews VM changes; `tofu apply` applies them.
- `flux reconcile kustomization apps --with-source` forces app sync after manifest changes.

## Coding Style & Naming Conventions
- Use 2-space indentation in YAML and Terraform for consistency.
- Hostnames follow the “habitats” theme (e.g., `golden-savanna`); VMs use “animals” (e.g., `sleepy-koala`).
- Kubernetes app manifests live in `kubernetes/apps/<app-name>/` and should include a `kustomization.yaml`.

## Testing Guidelines
- No unit test framework is defined; validate changes via tooling and dry runs.
- Prefer `tofu plan` for infra changes and `kubectl get`/`flux get` for cluster state checks.
- When adding apps, run `flux reconcile kustomization apps --with-source` and verify the namespace and pods.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits (e.g., `fix(observability): ...`, `chore: ...`).
- PRs should describe the intent, list affected hosts/apps, and link related issues.
- Include verification notes (e.g., `tofu plan`, `flux reconcile`, `kubectl get pods -A`).
- Never include decrypted secrets or SOPS keys; use `sops <file>.yaml` for edits.

## Security & Configuration Tips
- Keep secrets in `secrets/` and update `.sops.yaml` policies when adding new files.
- Prefer hostnames over IPs in inventories and manifests; Tailscale DNS is assumed.
