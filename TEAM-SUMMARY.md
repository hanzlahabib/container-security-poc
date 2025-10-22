# Container Security POC - Team Summary

**Repository:** https://github.com/hanzlahabib/container-security-demo

## 🎯 What This POC Demonstrates

This is a **hands-on, executable proof-of-concept** that demonstrates real-world container security vulnerabilities and their mitigations. Everything is automated with simple `make` commands.

## 🔥 Real-World Problem We're Solving

**Background:** The PDO incident where an insider gained root access to production through:
1. Running containers as root
2. Storing secrets in environment variables  
3. Using volume mounts without restrictions

**This POC shows:**
- ✅ How these attacks work (live demonstrations)
- ✅ How to prevent them (working secure implementations)
- ✅ Industry best practices from Google, Meta, Amazon, GitHub

---

## 📦 What's in the Repository

### 1. **Working Docker Containers** (`dockerfiles/`)

#### Insecure Container (Attack Target)
- Runs as **root** (UID 0)
- Secrets in **environment variables**
- Vulnerable to `docker inspect` theft
- Demonstrates the PDO-style vulnerabilities

#### Secure Container (Production-Ready)
- Runs as **non-root user** (UID 1001)
- Secrets in **volume-mounted files** at `/run/secrets`
- Health checks enabled
- Read-only filesystem support
- Real Node.js application that reads secrets securely

**Test Commands:**
```bash
make build-all       # Build both containers
make test-insecure   # See vulnerabilities in action
make test-secure     # See protections working
```

---

### 2. **Live Attack Scenarios** (`attack-scenarios/`)

#### Attack 1: Volume Mount Privilege Escalation
**File:** `01-volume-mount-attack.sh`

Demonstrates:
- How volume mounts can expose host filesystem
- Root container writing to host `/etc`
- How non-root containers prevent this

**Run:** `make attack-volume`

#### Attack 2: Secret Exposure via Environment Variables
**File:** `02-env-var-secret-exposure.sh`

Demonstrates:
- Stealing secrets via `docker inspect`
- Stealing secrets via `docker exec env`
- Reading secrets from `/proc/1/environ`
- Secure alternative: volume-mounted secrets

**Run:** `make attack-secrets`

---

### 3. **Real SOPS Encryption Demo** (`scripts/sops-demo.sh`)

**What it demonstrates:**
- Git-safe secret storage using SOPS + age
- Real AES256-GCM encryption (not mock!)
- How to encrypt secrets for GitOps workflows
- Proving decryption fails without the key

**Technology Used:**
- **SOPS 3.8.1** (Mozilla's Secret Operations tool)
- **age v1.1.1** (Modern encryption by Filippo Valsorda, Go team)
- Used by: AWS, CloudFlare, Datadog, thousands of companies

**Run:** `make sops-demo`
*(Automatically installs SOPS and age if missing)*

**What You'll See:**
1. Real encryption key generation
2. Plaintext secrets → Encrypted YAML
3. Successful decryption with key
4. Failed decryption without key (security proof)
5. Comparison: SOPS vs HashiCorp Vault

---

### 4. **Kubernetes Security Policies** (`kubernetes/`)

Production-ready manifests for:

#### Security Policies (OPA Gatekeeper)
- Block privileged containers
- Block hostPath volume mounts
- Require non-root users
- Enforce read-only root filesystem

#### Secrets Management
- External Secrets Operator configuration
- Vault integration example
- Secret rotation policies

#### Network Policies
- Zero-trust networking
- Ingress/egress rules
- Pod-to-pod communication restrictions

**Use Case:** Copy these to your Kubernetes clusters for enforcement

---

### 5. **HashiCorp Vault Setup** (`vault/`)

**What's Included:**
- Vault server configuration (`vault-config.hcl`)
- Application policies (`app-policy.hcl`)
- Setup automation script (`setup-vault.sh`)

**Demonstrates:**
- Dynamic secret generation
- Secret rotation
- Access control policies
- Audit logging

**Use Case:** For teams ready to adopt centralized secret management

---

### 6. **CI/CD Pipeline Examples** (`cicd/`)

#### GitLab CI (`gitlab/.gitlab-ci.yml`)
- Security scanning (Trivy)
- Secret scanning
- Container signing
- Vulnerability blocking

#### GitHub Actions (`github-actions/secure-build.yml`)
- Multi-stage Docker builds
- Security scanning integration
- Automated testing

**Use Case:** Copy these into your CI/CD pipelines

---

### 7. **Comprehensive Documentation** (`docs/`)

#### 01-SECURITY-OVERVIEW.md
- Defense-in-depth strategy (10 layers)
- Threat model analysis
- Best practices from FAANG companies

#### 02-SECRET-MANAGEMENT.md
- On-premises solutions comparison
- SOPS vs Vault vs Sealed Secrets
- Implementation guides

#### 03-ATTACK-SCENARIOS.md
- Detailed attack explanations
- Mitigation strategies
- Code examples

---

## 🚀 Quick Start for Team Members

### Option 1: Full Demo (5 minutes)
```bash
git clone https://github.com/hanzlahabib/container-security-demo.git
cd container-security-demo
make demo-all
```

**This will:**
1. Build insecure container
2. Demonstrate vulnerabilities (root user, secret theft)
3. Build secure container  
4. Show protections working
5. Display comparison summary

### Option 2: Quick Demo (2 minutes)
```bash
make quick-demo
```
(Uses pre-built images, faster)

### Option 3: Specific Tests

```bash
make test-insecure    # See vulnerability demonstrations
make test-secure      # See secure implementations
make attack-all       # Run both attack scenarios
make sops-demo        # SOPS encryption demo
make summary          # Show comparison table
```

---

## 📊 What Team Members Will Learn

### 1. **Security Vulnerabilities** (Hands-on)
- [ ] How secrets leak from environment variables
- [ ] How root containers enable privilege escalation
- [ ] How volume mounts can expose host filesystem
- [ ] Real attack patterns from PDO incident

### 2. **Secure Implementations** (Working Code)
- [ ] Non-root container configuration
- [ ] Volume-mounted secret management
- [ ] Health check implementation
- [ ] Read-only filesystem setup

### 3. **Production Tools** (Real Technology)
- [ ] SOPS encryption (used by AWS, CloudFlare)
- [ ] HashiCorp Vault integration
- [ ] Kubernetes security policies
- [ ] CI/CD security scanning

### 4. **Industry Best Practices**
- [ ] Google's Secret Manager approach
- [ ] Meta's Policy API Interface (PAI)
- [ ] Amazon's defense-in-depth
- [ ] GitHub's secret scanning

---

## 🎓 Use Cases for Team Presentation

### Scenario 1: Security Training (15 min)
```bash
1. Explain PDO incident background
2. Run: make test-insecure  (show vulnerabilities)
3. Run: make test-secure    (show fixes)
4. Run: make summary        (show comparison)
```

### Scenario 2: SOPS Adoption Discussion (10 min)
```bash
1. Explain GitOps secret challenge
2. Run: make sops-demo
3. Show encrypted file safe for Git
4. Discuss SOPS vs Vault tradeoffs
```

### Scenario 3: Kubernetes Security (20 min)
```bash
1. Review kubernetes/policies/
2. Explain OPA Gatekeeper enforcement
3. Demonstrate policy violations
4. Show External Secrets Operator
```

---

## 🔑 Key Takeaways for Team

### ❌ Don't Do This
- Store secrets in environment variables
- Run containers as root
- Use privileged containers in production
- Mount host paths without restrictions
- Skip security scanning in CI/CD

### ✅ Do This Instead
- Volume-mount secrets at `/run/secrets`
- Run as non-root user (UID 1000+)
- Drop all capabilities except required ones
- Use admission controllers (Gatekeeper)
- Implement defense-in-depth (10 layers)

---

## 📈 Adoption Path

### Phase 1: Immediate (This Week)
- [ ] Run demos with team
- [ ] Update Dockerfiles to non-root
- [ ] Move secrets from env vars to volumes

### Phase 2: Short-term (This Month)
- [ ] Install SOPS for GitOps workflows
- [ ] Add security scanning to CI/CD
- [ ] Implement Pod Security Standards

### Phase 3: Long-term (This Quarter)
- [ ] Deploy HashiCorp Vault
- [ ] Implement OPA Gatekeeper policies
- [ ] Set up External Secrets Operator

---

## 🛠️ Technology Stack

All tools in this POC are **production-ready** and **industry-standard**:

| Tool | Version | Used By | Purpose |
|------|---------|---------|---------|
| Docker | Latest | Everyone | Container runtime |
| SOPS | 3.8.1 | AWS, CloudFlare, Datadog | Secret encryption |
| age | 1.1.1 | Go team | Modern encryption |
| Vault | Latest | Uber, Reddit, Stripe | Secret management |
| OPA Gatekeeper | Latest | Netflix, Adobe | Policy enforcement |
| Trivy | Latest | Microsoft, Rakuten | Vulnerability scanning |

---

## 📞 Questions?

**Repository:** https://github.com/hanzlahabib/container-security-demo

**Quick Commands:**
```bash
make help          # Show all available commands
make docs          # Open documentation
make present       # Full team presentation (5 min)
make quick-present # Quick 2-minute demo
```

---

## ✅ This POC is:
- ✓ **Real** - Uses actual SOPS, Vault, OPA Gatekeeper
- ✓ **Automated** - One-command demos
- ✓ **Production-Ready** - Copy these patterns to production
- ✓ **Educational** - Explains vulnerabilities and fixes
- ✓ **Complete** - From attacks to mitigations to CI/CD

## ❌ This POC is NOT:
- ✗ Mock or simulation - Everything actually works
- ✗ Theoretical - All demos are executable
- ✗ Toy project - Uses industry-standard tools
- ✗ Complex - Simple `make` commands

---

**Ready to secure your containers? Start with:** `make demo-all`
