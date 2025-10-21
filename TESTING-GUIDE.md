# Testing Guide - Quick Start

This guide shows you how to **test everything locally** without needing a full Kubernetes cluster.

---

## 🎯 What You Can Test

1. ✅ **Docker Security** - Insecure vs Secure containers (5 minutes)
2. ✅ **Attack Scenarios** - Volume mount & secret exposure (10 minutes)
3. ✅ **Secret Management** - SOPS encryption (5 minutes)
4. ✅ **Kubernetes (Optional)** - If you have a cluster (30 minutes)

---

## Prerequisites

### Required (For Basic Tests)
```bash
# Check you have Docker installed
docker --version
# Need: Docker 20+ (Docker Desktop on Mac/Windows, Docker Engine on Linux)

# Install if missing:
# Mac: brew install docker
# Ubuntu/Debian: sudo apt-get install docker.io
# Windows: Download Docker Desktop from docker.com
```

### Optional (For Full Tests)
```bash
# For Kubernetes testing
kubectl version --client   # Need 1.28+
minikube version          # OR kind version

# For secret encryption
# SOPS - Download from: https://github.com/getsops/sops/releases
curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops

# Age - Download from: https://github.com/FiloSottile/age/releases
curl -LO https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
tar xf age-v1.1.1-linux-amd64.tar.gz
sudo mv age/age /usr/local/bin/
```

---

## Test 1: Docker Security Comparison (5 minutes)

### Test the INSECURE container

```bash
cd /home/hanzla/development/container-security-poc
cd dockerfiles/insecure

# Build insecure image
docker build -t insecure-app:latest .

# Run it
docker run -d --name insecure-test insecure-app:latest sleep infinity

echo "=== ATTACKING INSECURE CONTAINER ==="

# Attack 1: Check if running as root
docker exec insecure-test id
# ❌ Output: uid=0(root) gid=0(root) <- RUNNING AS ROOT!

# Attack 2: Steal secrets from environment variables
echo -e "\n=== STOLEN SECRETS ==="
docker exec insecure-test env | grep -E "PASSWORD|KEY|SECRET"
# ❌ Shows: DATABASE_PASSWORD=SuperSecret123, etc.

# Attack 3: Check via docker inspect
docker inspect insecure-test | jq '.[0].Config.Env' | grep -E "PASSWORD|KEY|SECRET"
# ❌ Secrets visible to anyone with docker access!

# Cleanup
docker stop insecure-test && docker rm insecure-test
docker rmi insecure-app:latest
```

### Test the SECURE container

```bash
cd ../secure

# Build secure image
docker build -t secure-app:latest .

# Create secret files (simulating Kubernetes secrets)
mkdir -p /tmp/test-secrets
echo "SuperSecret123" > /tmp/test-secrets/database-password
echo "sk-1234567890abcdef" > /tmp/test-secrets/api-key
chmod 600 /tmp/test-secrets/*

# Run secure container with volume-mounted secrets
docker run -d --name secure-test \
  -v /tmp/test-secrets:/run/secrets:ro \
  -p 8080:8080 \
  secure-app:latest

sleep 3

echo -e "\n=== TESTING SECURE CONTAINER ==="

# Test 1: Check user (should be non-root)
docker exec secure-test id
# ✅ Output: uid=1001(appuser) gid=1001(appuser) <- NOT ROOT!

# Test 2: Try to steal secrets from environment
echo -e "\n=== ATTEMPTING TO STEAL SECRETS ==="
docker exec secure-test env | grep -E "PASSWORD|KEY|SECRET" || echo "✅ NO SECRETS IN ENV VARS!"

# Test 3: Check via docker inspect
docker inspect secure-test | jq '.[0].Config.Env'
# ✅ No secrets visible!

# Test 4: Verify app can READ secrets from /run/secrets
echo -e "\n=== SECRETS AVAILABLE TO APP ==="
docker exec secure-test ls -la /run/secrets/
docker exec secure-test cat /run/secrets/database-password
# ✅ App can read secrets from files

# Test 5: Health check
echo -e "\n=== HEALTH CHECK ==="
curl http://localhost:8080/health
# ✅ Output: {"status":"healthy","uid":1001}

# Test 6: Try to become root (should fail)
echo -e "\n=== TRYING TO ESCALATE TO ROOT ==="
docker exec secure-test sudo su || echo "✅ Cannot become root!"

# Cleanup
docker stop secure-test && docker rm secure-test
docker rmi secure-app:latest
rm -rf /tmp/test-secrets
```

**What you learned:**
- ❌ Insecure: Runs as root, secrets in env vars, easily stolen
- ✅ Secure: Non-root user, secrets in files, not visible to docker inspect

---

## Test 2: Attack Scenario - Volume Mount Privilege Escalation (10 minutes)

This recreates the **PDO incident** mentioned in your team chat.

```bash
cd /home/hanzla/development/container-security-poc/attack-scenarios

# Make executable if not already
chmod +x 01-volume-mount-attack.sh

# Run the attack demonstration
./01-volume-mount-attack.sh
```

**What happens:**
1. Script creates container with host filesystem mounted at `/host`
2. Container can read ANY file on host (including `/etc/shadow`, SSH keys, secrets)
3. Demonstrates how `chroot /host` gives full host access
4. Shows why Docker access = root access (without proper controls)

**Expected Output:**
```
🚨 ATTACK SCENARIO: Volume Mount Privilege Escalation
==================================================

Step 1: Running container with host filesystem mounted...
✅ Inside container

Step 2: Exploring host filesystem...
<shows /etc files>

Step 3: Reading sensitive files...
<shows hostname, may show /etc/shadow>

Step 4: Searching for secrets...
<lists .env files, secret files found>

Step 5: Checking if we can chroot to host...
⚠️  Could execute: chroot /host
⚠️  This would give full host access!

🚨 ATTACK SUCCESSFUL!
====================
- Read host filesystem
- Found sensitive files
- Could potentially chroot to gain root access

MITIGATIONS:
1. ✅ Use Pod Security Standards (restricted)
2. ✅ Block hostPath volumes with admission controllers
3. ✅ RBAC - developers can't create pods
4. ✅ Use GitOps - no manual kubectl/docker commands
5. ✅ Audit logging - detect attempts
```

---

## Test 3: Attack Scenario - Secret Exposure (10 minutes)

```bash
chmod +x 02-env-var-secret-exposure.sh
./02-env-var-secret-exposure.sh
```

**What happens:**
1. Builds container with secrets in ENV vars
2. Shows 3 ways to steal secrets: `docker inspect`, `docker exec env`, `/proc/1/environ`
3. Rebuilds with secure approach (volume-mounted secrets)
4. Demonstrates secrets are NOT visible via docker inspect

**Expected Output:**
```
Step 3: ATTACKING - Stealing secrets via 'docker inspect'...
"DATABASE_PASSWORD=SuperSecret123"
"API_KEY=sk-1234567890abcdef"
❌ ATTACK SUCCESSFUL!

==================================================
SECURE ALTERNATIVE:
==================================================
Running secure container with volume-mounted secrets...

Attempting to steal secrets via 'docker inspect'...
✅ NO SECRETS IN ENVIRONMENT VARIABLES!

Secrets are in /run/secrets (read-only volume):
-r-------- 1 appuser appuser 15 Oct 21 12:34 database-password
-r-------- 1 appuser appuser 20 Oct 21 12:34 api-key

✅ Application reads from files
✅ But they're NOT visible in docker inspect!
```

---

## Test 4: Secret Encryption with SOPS (5 minutes)

Test encrypting secrets for Git storage (no Vault needed).

```bash
# Install age and sops first (see Prerequisites)

# Generate encryption key
age-keygen -o /tmp/age-key.txt
cat /tmp/age-key.txt
# Save this key! You'll need it to decrypt

# Get public key
PUBLIC_KEY=$(grep "public key:" /tmp/age-key.txt | cut -d: -f2 | tr -d ' ')
echo "Public Key: $PUBLIC_KEY"

# Create secrets file
cat > /tmp/secrets.yaml <<EOF
database:
  host: db.internal.com
  username: admin
  password: SuperSecret123
  port: 5432

api:
  key: sk-1234567890abcdef
  endpoint: https://api.example.com

aws:
  access_key: AKIAIOSFODNN7EXAMPLE
  secret_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

echo "=== ORIGINAL SECRETS (PLAINTEXT) ==="
cat /tmp/secrets.yaml

# Encrypt with SOPS
export SOPS_AGE_KEY_FILE=/tmp/age-key.txt
sops --encrypt --age "$PUBLIC_KEY" /tmp/secrets.yaml > /tmp/secrets.enc.yaml

echo -e "\n=== ENCRYPTED SECRETS (SAFE FOR GIT) ==="
cat /tmp/secrets.enc.yaml
# Notice: Keys are visible, but VALUES are encrypted!

# Decrypt
echo -e "\n=== DECRYPTING SECRETS ==="
sops --decrypt /tmp/secrets.enc.yaml

# Try without key (simulates attacker)
echo -e "\n=== TRYING TO DECRYPT WITHOUT KEY ==="
unset SOPS_AGE_KEY_FILE
sops --decrypt /tmp/secrets.enc.yaml 2>&1 || echo "❌ Cannot decrypt without key!"

# Cleanup
rm /tmp/secrets.yaml /tmp/secrets.enc.yaml /tmp/age-key.txt
```

**What you learned:**
- ✅ SOPS encrypts only VALUES, keeps KEYS visible for Git diffs
- ✅ Safe to commit encrypted files to Git
- ✅ Requires key to decrypt (attacker can't read)
- ✅ No infrastructure needed (just files)

---

## Test 5: Kubernetes Testing (Optional - 30 minutes)

### Option A: Using Minikube (Recommended for local testing)

```bash
# Start Minikube
minikube start --cpus=4 --memory=8192

# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Wait for Gatekeeper
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system \
  --timeout=300s

# Apply your security policies
cd /home/hanzla/development/container-security-poc
kubectl apply -f kubernetes/manifests/01-namespace.yaml
kubectl apply -f kubernetes/policies/

# Test hostPath blocking (SHOULD FAIL)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: secure-app
spec:
  containers:
  - name: app
    image: alpine
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
EOF

# Expected: Error about hostPath not allowed
# ✅ SECURITY WORKING!

# Test privileged container blocking (SHOULD FAIL)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: secure-app
spec:
  containers:
  - name: app
    image: alpine
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
EOF

# Expected: Error about privileged not allowed
# ✅ SECURITY WORKING!

# Test VALID secure pod (SHOULD SUCCEED)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  namespace: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
  containers:
  - name: app
    image: alpine
    command: ["sleep", "infinity"]
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF

# Check pod is running
kubectl get pod good-pod -n secure-app
# Should show: Running

# Verify it's non-root
kubectl exec -n secure-app good-pod -- id
# Should show: uid=1001

# Run security tests
cd scripts
chmod +x security-test.sh
./security-test.sh

# Cleanup
kubectl delete pod good-pod -n secure-app
minikube stop
```

### Option B: Using Kind (Kubernetes in Docker)

```bash
# Create Kind cluster
kind create cluster --name security-test

# Follow same steps as Minikube above

# Cleanup
kind delete cluster --name security-test
```

---

## Test 6: CI/CD Security Scanning (5 minutes)

Test security scanning tools locally:

```bash
cd /home/hanzla/development/container-security-poc

# Test 1: Secret Scanning with Gitleaks
# Install: https://github.com/gitleaks/gitleaks/releases
gitleaks detect --source . --verbose

# Should find no secrets (all encrypted or in .gitignore)

# Test 2: Create a file with a secret (test detection)
echo "aws_secret_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" > test-secret.txt
gitleaks detect --source . --verbose
# Should detect the secret!
rm test-secret.txt

# Test 3: Vulnerability scanning with Trivy
# Install: https://github.com/aquasecurity/trivy/releases
cd dockerfiles/secure
docker build -t secure-app:test .
trivy image secure-app:test

# Shows vulnerabilities in base image and dependencies

# Test 4: Scan Kubernetes manifests
cd ../../kubernetes/manifests
trivy config .

# Shows security issues in Kubernetes configs (if any)
```

---

## Test 7: Complete Integration Test (15 minutes)

Full end-to-end test:

```bash
cd /home/hanzla/development/container-security-poc

echo "=== Step 1: Building secure image ==="
cd dockerfiles/secure
docker build -t secure-app:integration .

echo -e "\n=== Step 2: Running attack scenarios ==="
cd ../../attack-scenarios
./01-volume-mount-attack.sh
./02-env-var-secret-exposure.sh

echo -e "\n=== Step 3: Testing SOPS encryption ==="
# (Run SOPS test from Test 4 above)

echo -e "\n=== Step 4: Kubernetes security (if available) ==="
# (Run Kubernetes tests from Test 5 above)

echo -e "\n=== Step 5: Security scanning ==="
# (Run scanning tests from Test 6 above)

echo -e "\n✅ ALL TESTS COMPLETE!"
```

---

## Quick Verification Checklist

After running tests, verify:

### Docker Security
- [ ] ✅ Secure container runs as UID 1001 (not root)
- [ ] ✅ No secrets visible in `docker inspect`
- [ ] ✅ Secrets readable from `/run/secrets` by app
- [ ] ✅ Health check responds on port 8080

### Attack Scenarios
- [ ] ✅ Volume mount attack demonstrates host filesystem access
- [ ] ✅ Env var attack shows secret theft methods
- [ ] ✅ Secure alternatives block both attacks

### Secret Encryption
- [ ] ✅ SOPS successfully encrypts secret values
- [ ] ✅ Keys remain visible (for Git diffs)
- [ ] ✅ Cannot decrypt without key file

### Kubernetes (if tested)
- [ ] ✅ hostPath volumes are blocked
- [ ] ✅ Privileged containers are blocked
- [ ] ✅ Root containers are blocked
- [ ] ✅ Secure pod runs successfully
- [ ] ✅ Security tests pass

---

## Troubleshooting

### Docker issues

**Problem:** Permission denied
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or use sudo: sudo docker ...
```

**Problem:** Port 8080 already in use
```bash
# Use different port
docker run -p 8081:8080 ...
curl http://localhost:8081/health
```

### SOPS issues

**Problem:** Command not found
```bash
# Install manually
wget https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
sops --version
```

### Kubernetes issues

**Problem:** Minikube won't start
```bash
minikube delete
minikube start --cpus=2 --memory=4096
# Lower resources if your machine is constrained
```

---

## What Each Test Proves

| Test | What It Demonstrates | Time |
|------|---------------------|------|
| **Test 1** | Secure vs insecure Docker patterns | 5 min |
| **Test 2** | Volume mount privilege escalation (PDO incident) | 10 min |
| **Test 3** | Secret exposure via environment variables | 10 min |
| **Test 4** | File-based secret encryption with SOPS | 5 min |
| **Test 5** | Kubernetes admission control & policies | 30 min |
| **Test 6** | CI/CD security scanning tools | 5 min |
| **Test 7** | Complete end-to-end integration | 15 min |

**Total Time:** ~25 minutes (without Kubernetes) or ~55 minutes (with Kubernetes)

---

## Next Steps

After testing locally:
1. Deploy to a test Kubernetes cluster
2. Set up Vault following [SETUP.md](./SETUP.md)
3. Configure CI/CD pipeline
4. Run security tests in your environment
5. Adapt configurations for your use case

---

## Getting Help

- **Documentation:** See `docs/` folder
- **Setup Guide:** See `SETUP.md`
- **Issues:** Check GitHub issues
- **Security Questions:** Review `docs/03-ATTACK-SCENARIOS.md`

---

**Remember:** These are DEMONSTRATIONS of security concepts. Adapt to your specific needs!
