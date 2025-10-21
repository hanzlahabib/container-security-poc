# Secret Management Guide

## Table of Contents
1. [On-Premises Secret Management Solutions](#on-premises-secret-management-solutions)
2. [Comparison Matrix](#comparison-matrix)
3. [Implementation Guides](#implementation-guides)
4. [Best Practices](#best-practices)

---

## On-Premises Secret Management Solutions

### Option 1: HashiCorp Vault (Self-Hosted) - RECOMMENDED

**Overview:**
- Can be fully self-hosted on your infrastructure
- Works in air-gapped environments (no internet required)
- Gold standard for enterprise secret management

**Deployment:**
```bash
# Docker
docker run -d --name=vault \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -v $(pwd)/vault/data:/vault/data \
  -v $(pwd)/vault/config:/vault/config \
  vault server

# Kubernetes (Helm)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3
```

**Features:**
- ✅ Dynamic secrets (auto-generated, time-limited)
- ✅ Automatic rotation
- ✅ Multiple authentication methods (AppRole, LDAP, Kubernetes)
- ✅ Encryption as a Service
- ✅ PKI/Certificate management
- ✅ Comprehensive audit logging
- ✅ Multi-cloud support
- ✅ High availability

**Best For:**
- Enterprise environments
- Multi-team organizations
- Regulated industries
- Complex secret management needs

---

### Option 2: Infisical (Open Source)

**Overview:**
- 100% open-source alternative
- Modern UI/UX
- Self-hostable on any infrastructure

**Deployment:**
```bash
# Docker Compose
curl -o docker-compose.yml https://infisical.com/docker-compose.yml
docker-compose up -d
```

**Features:**
- ✅ Secrets management
- ✅ Certificate management
- ✅ Privileged access management
- ✅ API-first design
- ✅ Multi-environment support
- ✅ Modern developer experience

**Best For:**
- Teams wanting modern UX
- Cost-conscious organizations
- Developers prioritizing ease of use

---

### Option 3: CyberArk Conjur Open Source

**Overview:**
- Enterprise-grade, free and open-source
- Designed for CI/CD pipelines
- Strong DevOps focus

**Deployment:**
```bash
# Docker
docker pull cyberark/conjur
docker run -d --name conjur \
  -p 443:443 \
  cyberark/conjur

# Kubernetes
kubectl apply -f https://github.com/cyberark/conjur-oss-helm-chart/releases/download/v2.0.0/conjur-oss.yaml
```

**Features:**
- ✅ Centralized secret storage
- ✅ RBAC
- ✅ Audit logging
- ✅ Native Kubernetes integration
- ✅ Jenkins, Chef, Puppet, Ansible support
- ✅ Designed for regulated industries

**Limitations:**
- ❌ No official support (community only)
- ❌ Enterprise features require paid version

**Best For:**
- Regulated industries
- Container/Kubernetes environments
- CI/CD heavy workflows

---

### Option 4: Mozilla SOPS + age (Lightweight)

**Overview:**
- File-based encryption
- No infrastructure required
- Git-friendly
- Perfect for simpler needs

**Installation:**
```bash
# Linux
curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops

# Install age
curl -LO https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
tar xf age-v1.1.1-linux-amd64.tar.gz
sudo mv age/age /usr/local/bin/
```

**Usage:**
```bash
# Generate key
age-keygen -o key.txt
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Create secrets file
cat > secrets.yaml <<EOF
database:
  host: localhost
  password: mySecretPassword123
  username: admin
EOF

# Encrypt
sops --encrypt --age age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p \
  secrets.yaml > secrets.enc.yaml

# Decrypt
export SOPS_AGE_KEY_FILE=key.txt
sops --decrypt secrets.enc.yaml

# Edit encrypted file directly
sops secrets.enc.yaml
```

**Features:**
- ✅ Only values encrypted (keys visible for Git diffs)
- ✅ Supports YAML, JSON, ENV, INI, Binary
- ✅ No external dependencies
- ✅ Git-friendly
- ✅ CNCF Sandbox project

**Limitations:**
- ❌ Manual key distribution
- ❌ No centralized access control
- ❌ Manual rotation
- ❌ No audit trail

**Best For:**
- Small teams
- GitOps workflows
- Simple secret needs
- Air-gapped environments

---

### Option 5: Kubernetes Sealed Secrets

**Overview:**
- Kubernetes-native solution
- Encrypts secrets for safe Git storage
- Controller decrypts in cluster

**Installation:**
```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xfz kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Usage:**
```bash
# Create sealed secret
kubectl create secret generic mysecret \
  --from-literal=password=mypassword \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > mysealedsecret.yaml

# Commit to Git (safe!)
git add mysealedsecret.yaml
git commit -m "Add sealed secret"

# Apply to cluster (controller decrypts)
kubectl apply -f mysealedsecret.yaml
```

**Features:**
- ✅ Kubernetes-native
- ✅ GitOps-friendly
- ✅ No external dependencies
- ✅ Cluster-specific encryption

**Limitations:**
- ❌ Kubernetes-only
- ❌ Can't share between clusters
- ❌ No automatic rotation
- ❌ Controller is single point of failure

**Best For:**
- Kubernetes-only environments
- GitOps workflows
- Teams avoiding external dependencies

---

### Option 6: External Secrets Operator (ESO)

**Overview:**
- Syncs secrets from external sources into Kubernetes
- Supports multiple backends

**Installation:**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets
```

**Usage with Vault:**
```yaml
# SecretStore pointing to self-hosted Vault
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.internal:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "my-app"
---
# ExternalSecret syncs from Vault to Kubernetes Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
  target:
    name: my-app-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: myapp/config
      property: password
```

**Features:**
- ✅ Centralized secret management
- ✅ Auto-sync capabilities
- ✅ Multiple backend support
- ✅ Kubernetes-native

**Best For:**
- Hybrid Vault + Kubernetes setup
- Multi-backend environments
- Automated secret synchronization

---

## Comparison Matrix

| Solution | Cost | Complexity | Features | On-Prem | Air-Gapped | UI | API | Audit |
|----------|------|------------|----------|---------|------------|-----|-----|-------|
| **Vault** | Free/Paid | High | ⭐⭐⭐⭐⭐ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Infisical** | Free | Medium | ⭐⭐⭐⭐ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Conjur** | Free/Paid | Medium | ⭐⭐⭐⭐ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **SOPS** | Free | Low | ⭐⭐ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Sealed Secrets** | Free | Low | ⭐⭐ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **ESO** | Free | Medium | ⭐⭐⭐ | ✅ | ✅ | ❌ | ✅ | Depends |

---

## Implementation Guides

### Scenario 1: Small Team, Simple Needs

**Recommendation:** SOPS + age

**Architecture:**
```
Developers → Git (encrypted secrets.enc.yaml)
                ↓
           CI/CD (decrypt with age key)
                ↓
           Deploy to servers
```

**Setup:**
1. Generate age key pair
2. Distribute public key to team
3. Encrypt secrets with SOPS
4. Store private key in CI/CD (secret variable)
5. Decrypt during deployment

**Cost:** $0
**Maintenance:** Minimal

---

### Scenario 2: Medium Organization, Kubernetes

**Recommendation:** Self-hosted Vault + External Secrets Operator

**Architecture:**
```
Vault (HA cluster)
  ↓
External Secrets Operator
  ↓
Kubernetes Secrets
  ↓
Pods (/run/secrets volume mount)
```

**Setup:**
1. Deploy Vault in HA mode (3 nodes)
2. Configure authentication (AppRole, Kubernetes)
3. Install External Secrets Operator
4. Create SecretStore resources
5. Create ExternalSecret resources
6. Secrets auto-sync to Kubernetes

**Cost:** Infrastructure only
**Maintenance:** Regular backups, updates

---

### Scenario 3: Enterprise, Regulated Industry

**Recommendation:** Vault Enterprise + Full Audit Stack

**Architecture:**
```
Vault Enterprise (HA + DR)
  ├─ HSM Integration (seal/unseal)
  ├─ Namespaces (multi-tenancy)
  ├─ Audit Logs → SIEM
  └─ Auto-rotation policies
       ↓
External Secrets Operator
       ↓
Kubernetes Secrets
       ↓
Pods (read-only /run/secrets)
```

**Setup:**
1. Deploy Vault Enterprise cluster
2. Integrate with HSM for seal
3. Configure LDAP/AD authentication
4. Set up namespaces per team
5. Enable audit logging to SIEM
6. Configure automatic rotation
7. Deploy ESO for Kubernetes sync
8. Implement disaster recovery

**Cost:** Enterprise licensing
**Maintenance:** Dedicated team

---

## Best Practices

### 1. Secret Lifecycle Management

```
Creation → Storage → Distribution → Rotation → Revocation
    ↓         ↓           ↓            ↓           ↓
  Strong  Encrypted  Least Priv.  Automated   Immediate
  Random  At Rest    Time-bound   Scheduled   On Breach
```

### 2. Never Store Secrets In

❌ Source code
❌ Docker images
❌ Environment variables (visible in `docker inspect`)
❌ ConfigMaps (plain text in Kubernetes)
❌ Git repositories (unencrypted)
❌ Build logs
❌ Error messages

### 3. Always Store Secrets In

✅ Dedicated secret managers (Vault, etc.)
✅ Encrypted at rest (KMS, HSM)
✅ Mounted as volumes (not env vars)
✅ File permissions 0400 (read-only)
✅ Temporary storage only

### 4. Access Control

```yaml
# Example Vault policy
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

path "secret/data/admin/*" {
  capabilities = ["deny"]
}
```

- Principle of least privilege
- Role-based access control (RBAC)
- Time-bound access tokens
- Regular access reviews
- MFA for sensitive operations

### 5. Rotation Strategy

**Frequency:**
- Passwords: 90 days
- API keys: 30 days
- Database credentials: 7 days (dynamic)
- TLS certificates: 90 days
- SSH keys: 180 days

**Process:**
1. Generate new secret
2. Deploy to applications
3. Wait for propagation
4. Revoke old secret
5. Verify no errors
6. Audit logs

### 6. Encryption Standards

- **Algorithm:** AES-256-GCM minimum
- **Key Management:** HSM or KMS
- **In Transit:** TLS 1.3
- **At Rest:** Encrypted volumes
- **Key Rotation:** Annual minimum

### 7. Audit and Compliance

**Log Everything:**
- Who accessed what secret
- When it was accessed
- From which system
- Was it successful
- Any modifications

**Alerts:**
- Failed authentication attempts
- Unusual access patterns
- Secret exposure attempts
- Policy violations
- Configuration changes

**Retention:**
- Logs: 1 year minimum
- Audit trails: 7 years (compliance)
- Secret versions: Last 5

### 8. Disaster Recovery

**Backup:**
- Encrypted backups daily
- Offsite storage
- Test restores monthly
- Document procedures

**High Availability:**
- 3+ replicas
- Load balancer
- Automated failover
- Health checks

**Recovery:**
- RTO (Recovery Time Objective): < 1 hour
- RPO (Recovery Point Objective): < 15 minutes
- Documented runbooks
- Regular drills

### 9. Developer Experience

**Make Security Easy:**
```bash
# Bad (manual, error-prone)
export DB_PASSWORD="hardcoded123"

# Good (automated, secure)
export DB_PASSWORD=$(vault kv get -field=password secret/myapp/db)
```

**Provide Tools:**
- CLI for secret retrieval
- SDK integrations
- Pre-commit hooks
- Secret scanning
- Documentation

### 10. Monitoring

**Metrics:**
- Secret access rate
- Failed authentication attempts
- Secret age (time since rotation)
- Vault health status
- API latency

**Dashboards:**
- Real-time access logs
- Secret inventory
- Compliance status
- Security alerts

---

## Migration Path

### Phase 1: Assessment (Week 1)
- [ ] Inventory all secrets
- [ ] Identify secret types
- [ ] Map dependencies
- [ ] Choose solution

### Phase 2: Pilot (Weeks 2-4)
- [ ] Deploy in non-production
- [ ] Test with 1-2 apps
- [ ] Document procedures
- [ ] Train team

### Phase 3: Migration (Weeks 5-8)
- [ ] Migrate non-critical secrets
- [ ] Update applications
- [ ] Implement rotation
- [ ] Remove hardcoded secrets

### Phase 4: Hardening (Weeks 9-12)
- [ ] Enable audit logging
- [ ] Set up monitoring
- [ ] Configure backups
- [ ] Security review
- [ ] Pen testing

---

## Quick Start Examples

See implementation examples in:
- [Vault Setup](../vault/)
- [SOPS Examples](../kubernetes/secrets/)
- [CI/CD Integration](../cicd/)
- [Attack Prevention](../attack-scenarios/)

---

## References

- [HashiCorp Vault Docs](https://developer.hashicorp.com/vault)
- [Mozilla SOPS](https://github.com/getsops/sops)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [Infisical](https://infisical.com/)
- [CyberArk Conjur](https://www.conjur.org/)
