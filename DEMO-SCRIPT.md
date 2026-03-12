# 10-Minute Demo Script — Trivy-Style GitHub Actions Attack

## Setup (before demo, ~5 mins)

1. Create two throwaway GitHub accounts:
   - `demo-victim-org` — owns the target repo
   - `demo-attacker` — will submit the malicious PR

2. Create repo `demo-victim-org/my-project` with:
   - `.github/workflows/vulnerable-ci.yml` (from this repo)
   - `scripts/test.sh` (legitimate version)
   - Add a dummy `PAT_TOKEN` secret in repo settings (value: `demo-token-12345`)

3. Fork `my-project` as `demo-attacker`

---

## Live Demo Flow

### Minute 0–1 — Context: What happened to Trivy?
- Trivy is a widely-used open source security scanner (20k+ stars)
- March 1, 2026: releases v0.27–v0.69 deleted, repo renamed, malicious VSCode extension published
- Root cause: one misconfigured GitHub Actions workflow

### Minute 1–3 — Explain the vulnerable pattern (show vulnerable-ci.yml)

Key points to highlight:
```
pull_request_target  →  runs in BASE repo context (has secrets)
checkout PR head     →  runs ATTACKER code
contents: write      →  full write access to releases, repo settings
```

The trap: `pull_request_target` was designed for workflows that need
secrets (e.g., to post comments on PRs from forks). But if you also
checkout and RUN the PR's code — you've handed the attacker the keys.

### Minute 3–6 — Live exploit walkthrough

1. As `demo-attacker`, fork the repo
2. Replace `scripts/test.sh` with `attacker-pr/test.sh`
3. Open PR against `demo-victim-org/my-project`
4. Show the Actions tab — workflow triggers automatically
5. Open the workflow run logs — show `PAT_TOKEN` printed in plain text

### Minute 6–8 — Show what attacker did with the token

With the leaked PAT, run these in terminal (use the demo token):

```bash
# Delete a release
gh release delete v0.1.0 --repo demo-victim-org/my-project --yes

# Make repo private
gh api repos/demo-victim-org/my-project \
  -X PATCH -f private=true

# Rename repo
gh api repos/demo-victim-org/my-project \
  -X PATCH -f name=totally-different-name
```

This is exactly what happened to Trivy — at scale.

### Minute 8–10 — The Fix (show fixed-ci.yml)

Three rules:
1. Never use `pull_request_target` + checkout PR code together
2. Use `pull_request` for untrusted code (runs in fork — no secrets)
3. Least privilege: `permissions: contents: read` by default

```yaml
# Safe split pattern:
# - Untrusted PR code  →  pull_request (no secrets)
# - Privileged ops     →  separate job, only on merge, base branch only
```

Bonus hardening:
- Pin Actions to full commit SHA (not @v4 tag)
- Use OpenSSF Scorecard to detect this automatically
- Enable GitHub's "required reviewers for workflows" setting

---

## Key Takeaway (one slide)

> `pull_request_target` + `checkout PR code` = RCE with your repo's secrets
> The Trivy attack deleted 5 years of releases in minutes using this pattern.

---

## Files in this repo

| File | Purpose |
|------|---------|
| `.github/workflows/vulnerable-ci.yml` | The bad pattern — use for demo |
| `.github/workflows/fixed-ci.yml` | The fix — show at the end |
| `scripts/test.sh` | Legit test script (base repo) |
| `attacker-pr/test.sh` | Attacker's malicious replacement |
