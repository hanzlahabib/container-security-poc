# Container Security & Secret Management - POC

A comprehensive proof-of-concept demonstrating enterprise-grade container security and secret management practices based on real-world scenarios and industry best practices from Google, Meta, Amazon, and GitHub.

## 🎯 Overview

This repository provides:
- **Security documentation** covering defense-in-depth strategies
- **Working examples** of secure vs insecure patterns
- **Attack scenarios** with mitigations
- **Production-ready configurations** for Kubernetes and Vault
- **Automated CI/CD pipelines** with security scanning
- **Testing scripts** to validate security posture

### Key Statistics (2024)
- **39 million secrets** leaked on GitHub in 2024
- **40% of breaches** involve stolen credentials
- **$5.2M average cost** of a data breach
- **23% of cloud breaches** due to misconfigurations

---

## 📚 Documentation

### Core Guides
1. **[Security Overview](./docs/01-SECURITY-OVERVIEW.md)** - Defense-in-depth strategy, threat models, industry best practices
2. **[Secret Management](./docs/02-SECRET-MANAGEMENT.md)** - On-premises solutions, comparison matrix, implementation guides
3. **[Attack Scenarios](./docs/03-ATTACK-SCENARIOS.md)** - Real-world attacks and mitigations

---

## 🗂️ Repository Structure

```
container-security-poc/
├── docs/                           # Comprehensive documentation
│   ├── 01-SECURITY-OVERVIEW.md     # Security principles and strategies
│   ├── 02-SECRET-MANAGEMENT.md     # Secret management solutions
│   └── 03-ATTACK-SCENARIOS.md      # Attack patterns and defenses
│
├── dockerfiles/                    # Docker examples
│   ├── insecure/                   # Anti-patterns (DON'T DO THIS)
│   │   └── Dockerfile              # Demonstrates common mistakes
│   └── secure/                     # Best practices (DO THIS)
│       ├── Dockerfile              # Production-ready secure image
│       ├── server.js               # Sample app with volume-mounted secrets
│       ├── healthcheck.js          # Health check implementation
│       └── package.json            # Dependencies
│
├── kubernetes/                     # Kubernetes configurations
│   ├── manifests/                  # Deployments and services
│   │   ├── 01-namespace.yaml      # Namespace with Pod Security Standards
│   │   ├── 02-secure-deployment.yaml  # Secure deployment example
│   │   └── 03-network-policy.yaml  # Zero-trust networking
│   ├── policies/                   # Admission control policies
│   │   ├── block-hostpath-volumes.yaml      # Prevent volume mount attacks
│   │   ├── require-non-root.yaml           # Enforce non-root containers
│   │   └── block-privileged-containers.yaml # Block privileged mode
│   └── secrets/                    # Secret management configs
│       └── external-secrets-operator.yaml  # ESO configuration
│
├── vault/                          # HashiCorp Vault setup
│   ├── config/                     # Vault configurations
│   │   └── vault-config.hcl        # Server configuration
│   ├── policies/                   # Vault policies
│   │   └── app-policy.hcl          # Application access policy
│   └── setup-vault.sh              # Automated setup script
│
├── cicd/                           # CI/CD pipeline examples
│   ├── gitlab/                     # GitLab CI
│   │   └── .gitlab-ci.yml          # Complete pipeline with security
│   └── github-actions/             # GitHub Actions
│       └── secure-build.yml        # Secure build workflow
│
├── attack-scenarios/               # Attack demonstrations
│   ├── 01-volume-mount-attack.sh   # PDO incident simulation
│   └── 02-env-var-secret-exposure.sh  # Secret stealing demo
│
├── scripts/                        # Automation scripts
│   └── security-test.sh            # Security validation tests
│
└── README.md                       # This file
```

---

## 🚀 Quick Start

### Prerequisites
- Docker 24+
- make
- Git

### 1. Clone Repository
```bash
git clone https://github.com/hanzlahabib/container-security-poc.git
cd container-security-poc
```

### 2. See All Available Commands
```bash
make help
```

### 3. Run Complete Demo (5 minutes)
```bash
make demo-all
```
This will:
- Build both insecure and secure containers
- Demonstrate vulnerabilities
- Show security protections
- Display comparison summary

### 4. Quick Commands

#### Build Containers
```bash
make build-all        # Build both insecure and secure images
make build-secure     # Build only secure image
make build-insecure   # Build only insecure image
```

#### Run Security Demos
```bash
make test-secure      # Test secure container protections
make test-insecure    # See vulnerabilities in action
make attack-all       # Run all attack scenarios
make sops-demo        # SOPS encryption demonstration
```

#### Team Presentation
```bash
make present          # Full 5-minute presentation
make quick-present    # Quick 2-minute demo
make summary          # Show security comparison table
```

### 5. Advanced Setup (Optional)

#### Kubernetes Deployment
```bash
# Create namespace with Pod Security Standards
kubectl apply -f kubernetes/manifests/01-namespace.yaml

# Deploy Gatekeeper policies
kubectl apply -f kubernetes/policies/

# Deploy application
kubectl apply -f kubernetes/manifests/02-secure-deployment.yaml
kubectl apply -f kubernetes/manifests/03-network-policy.yaml
```

#### Setup Vault (On-Premises)
```bash
make install-sops     # Install SOPS and age tools
cd vault
chmod +x setup-vault.sh
./setup-vault.sh
```

#### Kubernetes Security Tests
```bash
make kubernetes-test  # Run Kubernetes security validation
```

---

## 🎓 Learning Paths

### Path 1: Understanding Security Fundamentals
1. Read [Security Overview](./docs/01-SECURITY-OVERVIEW.md)
2. Compare [insecure](./dockerfiles/insecure/Dockerfile) vs [secure](./dockerfiles/secure/Dockerfile) Dockerfiles
3. Study [Attack Scenarios](./docs/03-ATTACK-SCENARIOS.md)

### Path 2: Implementing Secret Management
1. Read [Secret Management Guide](./docs/02-SECRET-MANAGEMENT.md)
2. Choose solution (Vault, SOPS, Sealed Secrets)
3. Follow setup scripts in `vault/`
4. Deploy with External Secrets Operator

### Path 3: Setting Up Production Security
1. Apply Pod Security Standards
2. Deploy Gatekeeper policies
3. Configure Network Policies
4. Set up Vault + ESO
5. Implement CI/CD security scanning
6. Run security tests

---

## 🔥 Attack Demonstrations

### Volume Mount Privilege Escalation (PDO Incident)
```bash
make attack-volume
```

**What it demonstrates:**
- How Docker access allows host filesystem access
- Why OS-level whitelisting isn't enough
- How to bypass restricted bash
- Why hostPath volumes must be blocked

**Mitigations:**
- Pod Security Standards (restricted)
- Gatekeeper policies blocking hostPath
- RBAC preventing pod creation
- GitOps (no manual commands)

### Secret Exposure via Environment Variables
```bash
make attack-secrets
```

**What it demonstrates:**
- How `docker inspect` reveals env var secrets
- Why secrets in environment variables are insecure
- How volume-mounted secrets are protected

**Mitigations:**
- Mount secrets as read-only volumes at `/run/secrets`
- Use Kubernetes Secrets + External Secrets Operator
- Never use ENV for secrets

### Run All Attack Scenarios
```bash
make attack-all
```

---

## 🏗️ Architecture Patterns

### Recommended Production Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        DEVELOPERS                           │
│         (No server access, No docker, No kubectl)           │
└────────────────────────┬────────────────────────────────────┘
                         │ git push
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      GIT REPOSITORY                         │
└────────────────────────┬────────────────────────────────────┘
                         │ webhook
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD PIPELINE                           │
│  • Build with secure base image                            │
│  • Security scan (Trivy, Grype)                             │
│  • Sign image (Cosign)                                      │
│  • Push to registry                                         │
│  • GitOps commit                                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   GITOPS CONTROLLER                         │
│              (ArgoCD/FluxCD)                                │
└────────────────────────┬────────────────────────────────────┘
                         │ sync
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                KUBERNETES CLUSTER                           │
│  • Admission Controllers (block bad configs)                │
│  • Pod Security Standards (restricted)                      │
│  • Network Policies (zero-trust)                            │
│  • RBAC (least privilege)                                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              EXTERNAL SECRETS OPERATOR                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│          HASHICORP VAULT (On-Premises)                      │
│  • Dynamic secrets                                          │
│  • Automatic rotation                                       │
│  • Audit logging                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Security Checklist

### Docker Security
- [ ] ✅ Use specific image tags (not `latest`)
- [ ] ✅ Use minimal base images (Alpine, distroless)
- [ ] ✅ Run as non-root user (USER 1001)
- [ ] ✅ No secrets in images or env vars
- [ ] ✅ Read-only root filesystem
- [ ] ✅ Health checks implemented
- [ ] ✅ Multi-stage builds
- [ ] ✅ Image scanning in CI/CD

### Kubernetes Security
- [ ] ✅ Pod Security Standards (restricted)
- [ ] ✅ Network Policies (default deny)
- [ ] ✅ RBAC (least privilege)
- [ ] ✅ No hostPath volumes
- [ ] ✅ No privileged containers
- [ ] ✅ Resource limits set
- [ ] ✅ Service accounts with minimal permissions
- [ ] ✅ Admission controllers enforcing policies

### Secret Management
- [ ] ✅ Centralized secret storage (Vault)
- [ ] ✅ Secrets mounted as volumes (not env vars)
- [ ] ✅ Automatic rotation enabled
- [ ] ✅ Audit logging configured
- [ ] ✅ Encrypted at rest and in transit
- [ ] ✅ No secrets in Git
- [ ] ✅ Pre-commit hooks for secret detection

### CI/CD Security
- [ ] ✅ Secret scanning (Gitleaks)
- [ ] ✅ Vulnerability scanning (Trivy)
- [ ] ✅ Image signing (Cosign)
- [ ] ✅ SBOM generation
- [ ] ✅ Container structure tests
- [ ] ✅ GitOps deployment
- [ ] ✅ Manual approval for production

---

## 🧪 Testing

### Quick Testing Commands
```bash
make demo-all         # Complete demo with all tests
make quick-demo       # Quick 2-minute demo
make compare          # Side-by-side security comparison
make summary          # Show comparison summary
```

### Attack & Security Tests
```bash
make test-insecure    # Test insecure container vulnerabilities
make test-secure      # Test secure container protections
make attack-all       # Run all attack scenarios
make sops-demo        # Test SOPS encryption
```

### Advanced Kubernetes Tests
```bash
make kubernetes-test  # Run Kubernetes security validation

# Or run script directly:
./scripts/security-test.sh
```

### Individual Kubernetes Tests
```bash
# Test Pod Security Standards
kubectl auth can-i create pods --as=system:serviceaccount:default:developer -n secure-app

# Test hostPath blocking
kubectl apply -f kubernetes/policies/block-hostpath-volumes.yaml

# Test privileged container blocking
kubectl apply -f kubernetes/policies/block-privileged-containers.yaml

# Test non-root enforcement
kubectl get pods -n secure-app -o json | jq '.items[].spec.securityContext.runAsNonRoot'
```

---

## 📊 Monitoring & Auditing

### Vault Audit Logs
```bash
kubectl exec -n vault vault-0 -- tail -f /vault/logs/audit.log
```

### Kubernetes Audit Logs
```bash
kubectl get events -n secure-app --sort-by='.lastTimestamp'
```

### Gatekeeper Violations
```bash
kubectl get constraints -A
kubectl describe constraint block-hostpath-volumes
```

---

## 🤝 Contributing

This is a proof-of-concept repository for educational purposes. Feel free to:
- Report issues
- Suggest improvements
- Submit pull requests
- Use as a template for your projects

---

## 📖 References

### Official Documentation
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [HashiCorp Vault](https://developer.hashicorp.com/vault)
- [External Secrets Operator](https://external-secrets.io/)

### Industry Resources
- [Google Secret Manager Best Practices](https://cloud.google.com/secret-manager/docs/best-practices)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)

### Security Standards
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

---

## ⚠️ Disclaimer

This repository contains intentionally insecure configurations for educational purposes. The attack scenarios should only be run in isolated environments. Never use insecure patterns in production.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

Based on real-world security incidents and best practices from:
- Google Cloud Security
- Meta Privacy Engineering
- AWS Security
- GitHub Advanced Security
- HashiCorp
- CNCF Security SIG

---

**Made with ❤️ for secure container deployments**
