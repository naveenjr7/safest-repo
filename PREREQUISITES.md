# Prerequisites — GitHub Actions Attack Demo

## 1. What is a Personal Access Token (PAT)?

A PAT is a token you manually create on GitHub to authenticate API calls or CLI operations **as yourself**.

- Created at: GitHub → Settings → Developer Settings → Personal Access Tokens
- Scoped to whatever permissions you grant (repos, org, delete, etc.)
- Persists until you revoke it or it expires
- **Can access all repos you own** if scoped broadly

```bash
# Example: using a PAT to call GitHub API
curl -H "Authorization: Bearer YOUR_PAT" \
  https://api.github.com/repos/owner/repo
```

**Risk:** If stolen, attacker operates as YOU — across all your repos and orgs.

---

## 2. What is GITHUB_TOKEN?

An automatically generated, short-lived token GitHub creates for **each workflow run**.

- No setup needed — always available as `${{ secrets.GITHUB_TOKEN }}`
- Scoped to the **current repo only**
- Expires when the workflow run ends
- Permissions controlled by the workflow's `permissions:` block

```yaml
# Available automatically in every workflow
env:
  GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Risk:** If stolen with `contents: write`, attacker can push malicious code or delete releases within that repo.

---

## 3. PAT vs GITHUB_TOKEN

| | PAT | GITHUB_TOKEN |
|--|--|--|
| Created by | You manually | GitHub automatically |
| Scope | All repos (if granted) | Current repo only |
| Lifetime | Until revoked | Duration of workflow run |
| Delete repo | Yes (if granted) | No |
| Cross-repo access | Yes | No |
| Controlled by workflow `permissions:` | No | Yes |

---

## 4. `pull_request` vs `pull_request_target`

### `pull_request`
```yaml
on:
  pull_request:
```
- Runs in the **fork's context** — isolated from base repo
- **No secrets** available
- **No write access** to base repo
- Default checkout: PR's merge commit (attacker's code) — but safe since no secrets
- Use for: running tests on PR code

### `pull_request_target`
```yaml
on:
  pull_request_target:
```
- Runs in the **base repo's context** — full access
- **Has secrets** available
- **Has write access** to base repo
- Default checkout: base branch (victim's trusted code)
- Use for: posting comments, adding labels, updating PR status

| | `pull_request` | `pull_request_target` |
|--|--|--|
| Runs on | Victim's Actions | Victim's Actions |
| Secrets | ❌ No | ✅ Yes |
| Write access | ❌ No | ✅ Yes |
| Default checkout | PR code | Base branch code |
| Safe to run PR code | ✅ Yes | ❌ No |

---

## 5. The Vulnerability — Root Cause

`pull_request_target` was designed to let maintainers interact with PRs from forks (post comments, add labels) — operations that need write access.

The mistake is combining it with checking out and running the PR's code:

```yaml
on:
  pull_request_target:        # ← has secrets (by design)

jobs:
  test:
    permissions:
      contents: write         # ← write access to repo
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # ← checks out attacker's code
      - run: bash ./scripts/test.sh   # ← runs attacker's code with secrets in env
        env:
          PAT_TOKEN: ${{ secrets.PAT_TOKEN }}   # ← secrets exposed
```

**Attack chain:**
```
attacker opens PR
       ↓
pull_request_target triggers (base repo context — has secrets)
       ↓
workflow checks out attacker's scripts/test.sh
       ↓
attacker's script runs with PAT_TOKEN in environment
       ↓
token exfiltrated → attacker uses it outside workflow
       ↓
delete releases, rename repo, make private, push malicious code
```

**Remove any one of these — attack fails:**
- Use `pull_request` instead of `pull_request_target`
- Don't checkout PR code in `pull_request_target`
- Don't pass secrets to the step running PR code

---

## 6. The Trivy Incident (March 1, 2026)

[Trivy](https://github.com/aquasecurity/trivy) is one of the most popular open source security scanners (20k+ stars), maintained by Aqua Security.

**What happened:**
- Attacker opened malicious PR #10252 on Feb 27, 2026
- Triggered a misconfigured `pull_request_target` workflow
- Leaked an org-level PAT with broad permissions
- Used the PAT to cause org-wide destruction

**Impact:**
| Action | Detail |
|--------|--------|
| Releases deleted | v0.27.0 – v0.69.1 wiped (5 years of releases) |
| Repo renamed | Temporarily |
| Repo made private | Temporarily |
| Malicious artifact published | VSCode extension on Open VSIX marketplace |
| Repo stars reset | Later restored by GitHub |
| Forks reassigned | To an unrelated repo |

**Fix (PR #10259):** Removed the vulnerable workflow pattern and applied least-privilege permissions.

---

## 7. The Safe Pattern

Split into two separate workflows — never mix secret access with PR code execution:

```yaml
# Workflow 1 — safe: run tests on PR code (no secrets)
on:
  pull_request:
jobs:
  test:
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4   # checks out PR code — safe, no secrets
      - run: bash ./scripts/test.sh
      - uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: results/

# Workflow 2 — safe: post results using secrets (no PR code)
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
jobs:
  comment:
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/download-artifact@v4  # reads results only
      - run: gh pr comment ...              # uses secrets safely
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 8. Resources

- [Trivy Incident Discussion](https://github.com/aquasecurity/trivy/discussions/10265)
- [pull_request_target — GitHub Docs](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request_target)
- [pull_request_nightmare — Orca Security](https://orca.security/resources/blog/pull-request-nightmare-github-actions-rce/)
- [hackerbot-claw Campaign — StepSecurity](https://www.stepsecurity.io/blog/hackerbot-claw-github-actions-exploitation)
- [Hardening GitHub Actions — Wiz Blog](https://www.wiz.io/blog/github-actions-security-guide)
- [Keeping GitHub Actions secure — GitHub Blog](https://github.blog/security/supply-chain-security/keeping-your-github-actions-and-workflows-secure-part-1-preventing-pwn-requests/)
