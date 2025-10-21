#!/bin/bash
# SOPS Encryption Demo Script
# Demonstrates how to encrypt secrets for Git storage

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   SOPS + age Encryption Demo${NC}"
echo -e "${BLUE}=========================================${NC}\n"

# Cleanup function
cleanup() {
    rm -f /tmp/age-key.txt /tmp/secrets.yaml /tmp/secrets.enc.yaml 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${YELLOW}Step 1: Generate encryption key${NC}"
echo "Command: age-keygen -o /tmp/age-key.txt"
age-keygen -o /tmp/age-key.txt 2>&1 | head -2

# Get public key
PUBLIC_KEY=$(grep "public key:" /tmp/age-key.txt | cut -d: -f2 | tr -d ' ')
echo -e "${GREEN}✓ Key generated${NC}"
echo -e "Public key: ${BLUE}${PUBLIC_KEY}${NC}\n"

echo -e "${YELLOW}Step 2: Create secrets file (plaintext)${NC}"
cat > /tmp/secrets.yaml <<EOF
# Application Secrets
database:
  host: db.internal.com
  port: 5432
  username: admin
  password: SuperSecret123

api:
  key: sk-1234567890abcdef
  endpoint: https://api.example.com

aws:
  access_key: AKIAIOSFODNN7EXAMPLE
  secret_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
  region: us-east-1
EOF

echo -e "${RED}=== ORIGINAL SECRETS (PLAINTEXT) ===${NC}"
cat /tmp/secrets.yaml
echo ""

echo -e "${YELLOW}Step 3: Encrypt secrets with SOPS${NC}"
echo "Command: sops --encrypt --age <public-key> secrets.yaml"
export SOPS_AGE_KEY_FILE=/tmp/age-key.txt
sops --encrypt --age "$PUBLIC_KEY" /tmp/secrets.yaml > /tmp/secrets.enc.yaml 2>/dev/null

echo -e "${GREEN}✓ Secrets encrypted${NC}\n"

echo -e "${GREEN}=== ENCRYPTED SECRETS (SAFE FOR GIT) ===${NC}"
echo -e "${BLUE}Notice: Keys are visible, but VALUES are encrypted!${NC}\n"
head -20 /tmp/secrets.enc.yaml
echo "... (more encrypted data) ..."
echo ""

echo -e "${YELLOW}Step 4: Decrypt secrets${NC}"
echo "Command: sops --decrypt secrets.enc.yaml"
echo ""
sops --decrypt /tmp/secrets.enc.yaml 2>/dev/null
echo ""

echo -e "${YELLOW}Step 5: Try to decrypt WITHOUT key (simulate attacker)${NC}"
unset SOPS_AGE_KEY_FILE
rm -f /tmp/age-key.txt

echo "Command: sops --decrypt secrets.enc.yaml"
if sops --decrypt /tmp/secrets.enc.yaml 2>&1 | grep -q "no key"; then
    echo -e "${GREEN}✓ Cannot decrypt without key!${NC}"
    echo -e "${GREEN}✓ Attacker with access to Git repository can't read secrets${NC}\n"
else
    echo -e "${RED}❌ Decryption should have failed${NC}\n"
fi

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   What This Demonstrates${NC}"
echo -e "${BLUE}=========================================${NC}\n"

echo -e "${GREEN}✓ Keys remain visible${NC} (for Git diffs)"
echo -e "${GREEN}✓ Values are encrypted${NC} (secure)"
echo -e "${GREEN}✓ Safe to commit to Git${NC} (encrypted)"
echo -e "${GREEN}✓ Can't decrypt without key${NC} (protected)"
echo -e "${GREEN}✓ No infrastructure needed${NC} (just files)\n"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Use Cases${NC}"
echo -e "${BLUE}=========================================${NC}\n"

echo "1. ${YELLOW}GitOps workflows${NC} - Commit encrypted secrets to Git"
echo "2. ${YELLOW}Developer machines${NC} - Each dev has own key"
echo "3. ${YELLOW}CI/CD pipelines${NC} - Decrypt secrets at build time"
echo "4. ${YELLOW}Kubernetes${NC} - Use with FluxCD for GitOps"
echo "5. ${YELLOW}Team collaboration${NC} - Share encrypted secrets safely\n"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Comparison: SOPS vs Vault${NC}"
echo -e "${BLUE}=========================================${NC}\n"

echo -e "${GREEN}SOPS:${NC}"
echo "  ✓ No infrastructure required"
echo "  ✓ Git-native workflow"
echo "  ✓ Simple to use"
echo "  ✗ Manual key distribution"
echo "  ✗ No automatic rotation"
echo "  ✗ No audit trail\n"

echo -e "${GREEN}Vault:${NC}"
echo "  ✓ Centralized management"
echo "  ✓ Automatic rotation"
echo "  ✓ Audit logging"
echo "  ✗ Requires infrastructure"
echo "  ✗ More complex setup"
echo "  ✗ Need network access\n"

echo -e "${YELLOW}💡 Best Practice:${NC}"
echo "Use SOPS for: Config management, GitOps, simple needs"
echo "Use Vault for: Dynamic secrets, enterprise, compliance\n"

echo -e "${GREEN}✅ SOPS Demo Complete!${NC}\n"
