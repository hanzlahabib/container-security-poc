# Complete Setup Guide

This guide walks you through setting up the entire security infrastructure from scratch.

## Prerequisites

### Required Tools
```bash
# Verify installations
docker --version          # Docker 24+
kubectl version --client  # Kubernetes 1.28+
helm version             # Helm 3+
git --version            # Git 2+
jq --version             # jq for JSON parsing
```

### Optional Tools (for full functionality)
```bash
trivy --version          # Vulnerability scanning
cosign version           # Image signing
gitleaks version         # Secret scanning
yq --version             # YAML processing
```

---

## Step-by-Step Setup

### Phase 1: Local Development (30 minutes)

#### 1. Build and Test Secure Docker Image
```bash
cd dockerfiles/secure

# Build image
docker build -t secure-app:v1.0.0 .

# Verify non-root user
docker run --rm secure-app:v1.0.0 id
# Expected: uid=1001(appuser) gid=1001(appuser)

# Test with secrets
mkdir -p /tmp/test-secrets
echo "test-password" > /tmp/test-secrets/database-password
echo "test-api-key" > /tmp/test-secrets/api-key

# Run with volume-mounted secrets
docker run -d --name test-app \
  -v /tmp/test-secrets:/run/secrets:ro \
  -p 8080:8080 \
  secure-app:v1.0.0

# Verify secrets are NOT in environment
docker inspect test-app | jq '.[0].Config.Env'
# Should NOT contain secrets!

# Verify app can read secrets
docker exec test-app cat /run/secrets/database-password
# Should output: test-password

# Check health
curl http://localhost:8080/health
# Expected: {"status":"healthy","uid":1001}

# Cleanup
docker stop test-app && docker rm test-app
rm -rf /tmp/test-secrets
```

#### 2. Run Attack Scenarios
```bash
cd ../attack-scenarios

# Volume mount privilege escalation
./01-volume-mount-attack.sh
# Read through the output to understand the attack

# Secret exposure via env vars
./02-env-var-secret-exposure.sh
# Compare insecure vs secure approaches
```

---

### Phase 2: Kubernetes Cluster Setup (1-2 hours)

#### 1. Create Namespace with Pod Security Standards
```bash
cd kubernetes/manifests

# Apply namespace
kubectl apply -f 01-namespace.yaml

# Verify Pod Security Standards
kubectl get ns secure-app -o json | \
  jq '.metadata.labels["pod-security.kubernetes.io/enforce"]'
# Expected: "restricted"
```

#### 2. Install Gatekeeper (Admission Controller)
```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Wait for Gatekeeper to be ready
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system \
  --timeout=300s

# Apply security policies
cd kubernetes/policies
kubectl apply -f block-hostpath-volumes.yaml
kubectl apply -f require-non-root.yaml
kubectl apply -f block-privileged-containers.yaml

# Verify policies are active
kubectl get constrainttemplates
```

#### 3. Test Security Policies
```bash
# Try to create pod with hostPath (should fail)
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
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
EOF

# Expected: Error with "hostPath volumes are not allowed"

# Try to create privileged pod (should fail)
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
    securityContext:
      privileged: true
EOF

# Expected: Error with "privileged containers are not allowed"
```

#### 4. Apply Network Policies
```bash
cd kubernetes/manifests
kubectl apply -f 03-network-policy.yaml

# Verify network policies
kubectl get networkpolicies -n secure-app
```

---

### Phase 3: HashiCorp Vault Setup (1 hour)

#### 1. Install Vault
```bash
cd vault

# Run automated setup
./setup-vault.sh

# IMPORTANT: Save the output!
# - vault-keys.json contains unseal keys and root token
# - Store in secure location (password manager, hardware key, etc.)
# - Delete from server after backup
```

#### 2. Access Vault UI
```bash
# Port forward to access Vault UI
kubectl port-forward -n vault vault-0 8200:8200

# Open browser: http://localhost:8200
# Login with root token from vault-keys.json
```

#### 3. Verify Vault Setup
```bash
# Set environment variables
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='<root-token-from-vault-keys.json>'

# Check Vault status
vault status

# List secrets
vault kv list secret/

# Read sample secret
vault kv get secret/myapp/database
```

---

### Phase 4: External Secrets Operator (30 minutes)

#### 1. Install External Secrets Operator
```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace

# Verify installation
kubectl get pods -n external-secrets
```

#### 2. Configure SecretStore
```bash
cd kubernetes/secrets

# Apply SecretStore and ExternalSecret
kubectl apply -f external-secrets-operator.yaml

# Verify SecretStore
kubectl get secretstore -n secure-app

# Check ExternalSecret status
kubectl get externalsecret -n secure-app
kubectl describe externalsecret app-secrets -n secure-app

# Verify Kubernetes Secret was created
kubectl get secret app-secrets -n secure-app
```

#### 3. Verify Secret Sync
```bash
# Check secret contents (base64 encoded)
kubectl get secret app-secrets -n secure-app -o json | \
  jq '.data | map_values(@base64d)'

# Should show synced values from Vault
```

---

### Phase 5: Deploy Application (15 minutes)

#### 1. Deploy Secure Application
```bash
cd kubernetes/manifests

# Apply deployment
kubectl apply -f 02-secure-deployment.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=secure-app \
  -n secure-app \
  --timeout=300s

# Check pods
kubectl get pods -n secure-app
```

#### 2. Verify Application Security
```bash
# Check pod runs as non-root
kubectl get pod -n secure-app -o json | \
  jq '.items[0].spec.securityContext.runAsUser'
# Expected: 1001

# Verify secrets are volume-mounted
kubectl get pod -n secure-app -o json | \
  jq '.items[0].spec.volumes[] | select(.name=="secrets")'

# Check no secrets in env vars
kubectl get pod -n secure-app -o json | \
  jq '.items[0].spec.containers[0].env'
# Should be empty or minimal

# Exec into pod and verify
POD_NAME=$(kubectl get pod -n secure-app -l app=secure-app -o jsonpath='{.items[0].metadata.name}')

# Check user
kubectl exec -n secure-app $POD_NAME -- id
# Expected: uid=1001(appuser)

# Check secrets location
kubectl exec -n secure-app $POD_NAME -- ls -la /run/secrets
# Should show secret files
```

---

### Phase 6: CI/CD Setup (1 hour)

#### Option A: GitLab CI

1. Add `.gitlab-ci.yml` to your repository:
```bash
cp cicd/gitlab/.gitlab-ci.yml .gitlab-ci.yml
```

2. Configure GitLab CI variables:
```
Settings → CI/CD → Variables

Add:
- CI_REGISTRY_USER
- CI_REGISTRY_PASSWORD
- COSIGN_PRIVATE_KEY
- COSIGN_PASSWORD
- GITOPS_TOKEN
```

3. Push to GitLab and verify pipeline runs

#### Option B: GitHub Actions

1. Add workflow to your repository:
```bash
mkdir -p .github/workflows
cp cicd/github-actions/secure-build.yml .github/workflows/
```

2. Configure GitHub Secrets:
```
Settings → Secrets and variables → Actions

Add:
- GITOPS_TOKEN
```

3. Push to GitHub and verify Actions run

---

### Phase 7: Security Testing (15 minutes)

#### Run Automated Security Tests
```bash
cd scripts

# Run all security tests
./security-test.sh

# Expected output:
# ✅ PASS: Namespace has restricted Pod Security Standard
# ✅ PASS: Developers cannot create pods
# ✅ PASS: hostPath volumes are blocked
# ✅ PASS: Privileged containers are blocked
# ... etc
```

#### Manual Security Verification
```bash
# Test RBAC
kubectl auth can-i create pods \
  --as=system:serviceaccount:default:developer \
  -n secure-app
# Expected: no

# Test image for vulnerabilities
trivy image secure-app:v1.0.0

# Test Kubernetes manifests
trivy config kubernetes/manifests/
```

---

## Troubleshooting

### Vault Issues

**Problem:** Vault pods not starting
```bash
kubectl get pods -n vault
kubectl logs vault-0 -n vault
```

**Solution:** Check vault-config.hcl and ensure storage backend is correct

**Problem:** Vault sealed
```bash
vault status
# Shows "Sealed: true"
```

**Solution:** Unseal Vault
```bash
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### External Secrets Operator Issues

**Problem:** ExternalSecret not syncing
```bash
kubectl get externalsecret -n secure-app
kubectl describe externalsecret app-secrets -n secure-app
```

**Solution:** Check Vault authentication and policy
```bash
# Verify Kubernetes auth is enabled
vault auth list

# Verify policy exists
vault policy read myapp-policy

# Verify role exists
vault read auth/kubernetes/role/myapp
```

### Pod Security Issues

**Problem:** Pod rejected due to security policy
```bash
kubectl get events -n secure-app --sort-by='.lastTimestamp'
```

**Solution:** Update pod spec to comply with restricted PSS:
- Set `runAsNonRoot: true`
- Set `runAsUser: 1001`
- Set `allowPrivilegeEscalation: false`
- Drop all capabilities
- No hostPath, hostNetwork, hostPID, hostIPC

---

## Next Steps

1. **Enable Secret Rotation**
```bash
# Configure automatic rotation in Vault
vault write database/config/mydb rotation_period=24h
```

2. **Set Up Monitoring**
```bash
# Install Prometheus and Grafana
# Configure alerts for:
# - Failed authentication attempts
# - Privileged container attempts
# - Policy violations
```

3. **Implement Disaster Recovery**
```bash
# Set up Vault backups
# Test restore procedures
# Document runbooks
```

4. **Security Hardening**
```bash
# Enable HSM for Vault auto-unseal
# Implement service mesh (Istio/Linkerd)
# Add runtime security (Falco)
# Enable audit logging to SIEM
```

---

## Production Checklist

Before going to production:

- [ ] All secrets migrated to Vault
- [ ] Automatic rotation configured
- [ ] Audit logging enabled and monitored
- [ ] Backups configured and tested
- [ ] Disaster recovery procedures documented
- [ ] Pod Security Standards enforced
- [ ] Admission controllers active
- [ ] Network policies applied
- [ ] RBAC configured with least privilege
- [ ] CI/CD security scanning enabled
- [ ] Image signing implemented
- [ ] Monitoring and alerting configured
- [ ] Incident response plan documented
- [ ] Security team trained
- [ ] Penetration testing completed

---

## Getting Help

- Read the documentation in `docs/`
- Review attack scenarios in `attack-scenarios/`
- Check GitHub issues
- Review official documentation:
  - [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
  - [Vault Documentation](https://developer.hashicorp.com/vault)
  - [External Secrets](https://external-secrets.io/)

---

**Remember:** Security is a journey, not a destination. Continuously review and improve your security posture.
