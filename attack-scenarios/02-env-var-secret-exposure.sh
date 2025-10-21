#!/bin/bash
# Attack Scenario: Secret Exposure via Environment Variables
# Demonstrates how secrets in env vars are easily stolen

set -e

echo "🚨 ATTACK SCENARIO: Secret Exposure via Environment Variables"
echo "=============================================================="
echo ""

# Build insecure image with secrets in env vars
echo "Step 1: Building insecure container with hardcoded secrets..."
docker build -t insecure-app:latest -f - . <<'EOF'
FROM alpine
ENV DATABASE_PASSWORD=SuperSecret123
ENV API_KEY=sk-1234567890abcdef
ENV AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
CMD ["sleep", "infinity"]
EOF

echo ""
echo "Step 2: Running container..."
CONTAINER_ID=$(docker run -d insecure-app:latest)
echo "Container ID: $CONTAINER_ID"

sleep 2

echo ""
echo "Step 3: ATTACKING - Stealing secrets via 'docker inspect'..."
echo "Command: docker inspect $CONTAINER_ID | jq '.[0].Config.Env'"
echo ""

docker inspect $CONTAINER_ID | jq '.[0].Config.Env[] | select(contains("PASSWORD") or contains("KEY") or contains("SECRET"))'

echo ""
echo "Step 4: Alternative attack - exec into container..."
echo "Command: docker exec $CONTAINER_ID env"
echo ""

docker exec $CONTAINER_ID env | grep -E "PASSWORD|KEY|SECRET"

echo ""
echo "Step 5: Alternative attack - read from /proc..."
docker exec $CONTAINER_ID sh -c 'cat /proc/1/environ | tr "\0" "\n" | grep -E "PASSWORD|KEY|SECRET"'

echo ""
echo "🚨 ATTACK SUCCESSFUL!"
echo "===================="
echo "Stolen secrets:"
echo "- DATABASE_PASSWORD"
echo "- API_KEY"
echo "- AWS_SECRET_KEY"
echo ""

# Cleanup
echo "Cleaning up..."
docker stop $CONTAINER_ID >/dev/null
docker rm $CONTAINER_ID >/dev/null
docker rmi insecure-app:latest >/dev/null

echo ""
echo "=================================================="
echo "SECURE ALTERNATIVE:"
echo "=================================================="
echo ""

# Build secure image
echo "Building secure container..."
docker build -t secure-app:latest -f - . <<'EOF'
FROM alpine
RUN mkdir -p /run/secrets && chmod 700 /run/secrets
RUN adduser -D -u 1001 appuser
USER appuser
CMD ["sleep", "infinity"]
EOF

echo ""
echo "Running secure container with volume-mounted secrets..."

# Create secret files
mkdir -p /tmp/secrets
echo "SuperSecret123" > /tmp/secrets/database-password
echo "sk-1234567890abcdef" > /tmp/secrets/api-key
chmod 644 /tmp/secrets/*  # Make readable by container user

SECURE_ID=$(docker run -d \
    -v /tmp/secrets:/run/secrets:ro \
    secure-app:latest)

sleep 2

echo ""
echo "Attempting to steal secrets via 'docker inspect'..."
docker inspect $SECURE_ID | jq '.[0].Config.Env'

echo ""
echo "✅ NO SECRETS IN ENVIRONMENT VARIABLES!"
echo ""

echo "Secrets are in /run/secrets (read-only volume):"
docker exec $SECURE_ID ls -la /run/secrets/

echo ""
echo "Application reads from files:"
docker exec $SECURE_ID cat /run/secrets/database-password

echo ""
echo "But they're NOT visible in docker inspect!"
echo ""

# Cleanup
docker stop $SECURE_ID >/dev/null
docker rm $SECURE_ID >/dev/null
docker rmi secure-app:latest >/dev/null
rm -rf /tmp/secrets

echo "=================================================="
echo "MITIGATIONS:"
echo "=================================================="
echo "1. ✅ NEVER use environment variables for secrets"
echo "2. ✅ Mount secrets as read-only volumes at /run/secrets"
echo "3. ✅ Use Kubernetes Secrets or Vault"
echo "4. ✅ Use External Secrets Operator for sync"
echo "5. ✅ File permissions 0400 (read-only)"
echo ""
echo "See: dockerfiles/secure/Dockerfile"
echo "See: kubernetes/secrets/external-secrets-operator.yaml"
