---
description: Commit, push, and trigger Flux reconciliation
agent: build
---

Please help me commit my changes, push them, and trigger Flux reconciliation.

First, check the current git status to see what files are staged or modified:
!`git status`

Then, check recent commits to understand the commit message style:
!`git log --oneline -10`

Based on the changes and the repository's commit conventions (Conventional Commits with types like fix, feat, chore, etc.), suggest a commit message in the format: `<type>(<scope>): <description>`

Ask me to confirm or modify the commit message, then:
1. Stage any unstaged changes if needed: `git add <files>`
2. Commit with the conventional commit message: `git commit -m "<type>(<scope>): <description>"`
3. Push to remote: `git push`
4. Trigger Flux reconciliation: `flux reconcile kustomization apps --with-source`
5. Verify the reconciliation by checking pod status: `kubectl get pods -A`

Show me the output of each step and confirm when everything is complete.
