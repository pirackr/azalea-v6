# Postgres Migration: Longhorn to local-path (Blue/Green)

This runbook migrates Postgres from the existing CNPG cluster (`postgres`) on `longhorn` to a new CNPG cluster (`postgres-local`) on `local-path`.

## Preconditions

- `local-path` storage class is installed and healthy.
- Flux has synced `kubernetes/apps/postgres/cluster-local.yaml`.
- You can run `kubectl` against the homelab cluster.

## 1) Reconcile and verify green cluster

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && flux reconcile kustomization apps --with-source'
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n postgres get cluster'
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n postgres get pvc'
```

Expected:
- `postgres` and `postgres-local` both appear.
- `postgres-local` PVC is bound to `local-path`.

## 2) Create local backup directory

```bash
mkdir -p "$HOME/backups/postgres-migration"
```

## 3) Dump old cluster locally

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n postgres exec postgres-1 -- sh -lc "PGPASSWORD=$(kubectl -n postgres get secret postgres-nextcloud -o jsonpath={.data.password} | base64 -d) pg_dump -h postgres-rw.postgres.svc.cluster.local -U nextcloud -d nextcloud -Fc" > "$HOME/backups/postgres-migration/nextcloud-pre-cutover.dump"'
```

If `postgres-1` is not the current primary pod name, replace it with the pod returned by:

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n postgres get pods -l cnpg.io/cluster=postgres'
```

## 4) Restore into green cluster

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && PGPASSWORD=$(kubectl -n postgres get secret postgres-nextcloud -o jsonpath={.data.password} | base64 -d) && cat "$HOME/backups/postgres-migration/nextcloud-pre-cutover.dump" | kubectl -n postgres exec -i postgres-local-1 -- env PGPASSWORD="$PGPASSWORD" pg_restore -h postgres-local-rw.postgres.svc.cluster.local -U nextcloud -d nextcloud --clean --if-exists --no-owner --no-privileges'
```

Quick verification:

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && PGPASSWORD=$(kubectl -n postgres get secret postgres-nextcloud -o jsonpath={.data.password} | base64 -d) && kubectl -n postgres exec postgres-local-1 -- env PGPASSWORD="$PGPASSWORD" psql -h postgres-local-rw.postgres.svc.cluster.local -U nextcloud -d nextcloud -c "SELECT now();"'
```

## 5) Cutover with short downtime

1. Scale down Nextcloud:

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n nextcloud scale deployment/nextcloud --replicas=0'
```

2. Take final dump from old cluster (same command as step 3) and overwrite the dump file.
3. Restore final dump into `postgres-local` (same command as step 4).
4. Update `POSTGRES_HOST` in `kubernetes/apps/nextcloud/deployment.yaml` to:

```text
postgres-local-rw.postgres.svc.cluster.local
```

5. Reconcile apps and scale Nextcloud back up:

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && flux reconcile kustomization apps --with-source'
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n nextcloud scale deployment/nextcloud --replicas=1'
```

## 6) Post-cutover checks

```bash
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n postgres get cluster,pods,svc,pvc'
nix develop --command bash -lc 'export KUBECONFIG=$HOME/.kube/config-azalea && kubectl -n nextcloud get pods'
```

Validate in app:
- Login works.
- Existing files are visible.
- New upload works.

## 7) Rollback (during confidence window)

- Set `POSTGRES_HOST` back to `postgres-rw.postgres.svc.cluster.local` in `kubernetes/apps/nextcloud/deployment.yaml`.
- Reconcile apps.

## 8) Cleanup after confidence window

- Remove old `postgres` cluster from `kubernetes/apps/postgres/kustomization.yaml`.
- Delete `kubernetes/apps/postgres/cluster.yaml` when ready.
- Reconcile apps and confirm old Longhorn PVCs are gone.
