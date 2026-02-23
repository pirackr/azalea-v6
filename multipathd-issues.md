# multipathd Issues Summary

## What happened

- Longhorn reported `MultipathdIsRunning` on all storage nodes (`chunky-wombat`, `fancy-penguin`, `lazy-panda`).
- During the same incident window, Longhorn showed repeated replica rebuild failures, degraded volumes, and frequent rebuild retries.
- Symptoms included errors like `context deadline exceeded`, `connection reset by peer`, failed rebuild/failed purge events, and replica churn.

## Why this matters

- `multipathd` can interfere with Longhorn block-device handling.
- In this cluster, that condition aligned with unstable replica rebuild behavior and prolonged recovery after node/network disruption.
- Longhorn itself flags running `multipathd` as a known risk on nodes.

## Actions taken

- Disabled and stopped `multipathd` and `multipathd.socket` on:
  - `chunky-wombat`
  - `fancy-penguin`
  - `lazy-panda`
- Masked both units on each node to prevent accidental restart.
- Kept Longhorn rebuild pressure low by:
  - setting `concurrent-replica-rebuild-per-node-limit=1`
  - setting `replica-auto-balance=disabled`

## Verification after changes

- Longhorn node condition now shows `multipath=True` on all three nodes (healthy condition, no active multipath warning).
- Volume state converged back to healthy across the cluster.
- Rebuild storms subsided compared with the earlier recovery period.

## Residual notes

- Historical warning/error events from the earlier outage window remain visible in Kubernetes events/log history.
- Current snapshots are healthy, but historical logs still show prior rebuild failures during that period.

## Follow-up recommendations

- Persist this as infrastructure policy (Ansible/Nix/cloud-init), not only manual runtime changes.
- Keep Longhorn rebuild concurrency conservative in this environment.
- Continue monitoring for recurring replica churn after host/node restarts.
- If Longhorn instability recurs, evaluate storage migration path (OpenEBS/Ceph) with staged app-by-app PVC migration.
