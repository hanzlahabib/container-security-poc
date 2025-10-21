# Container Security & Secret Management - Comprehensive Guide

## Table of Contents
1. [Introduction](#introduction)
2. [The Security Problem](#the-security-problem)
3. [Defense-in-Depth Strategy](#defense-in-depth-strategy)
4. [Threat Models](#threat-models)
5. [Industry Best Practices](#industry-best-practices)

---

## Introduction

This document provides a comprehensive overview of container security and secret management based on real-world scenarios and industry best practices from Google, Meta, Amazon, and GitHub.

### Key Statistics (2024)
- **39 million secrets leaked** on GitHub in 2024
- **40% of breaches** involve stolen credentials
- **83% of organizations** experienced ≥1 cloud security incident
- **$5.2M average cost** of a data breach
- **23% of cloud breaches** due to misconfigurations

---

## The Security Problem

### External Threats
- Unauthorized access to systems
- Credential theft
- Secret exposure in code repositories
- Man-in-the-middle attacks
- Supply chain attacks

### Internal Threats (CRITICAL)
- Developers/operators with Docker daemon access
- Privilege escalation via volume mounts
- Container breakout attacks
- Insider access to secrets
- Accidental secret exposure

### Real-World Attack: Volume Mount Privilege Escalation

**Attack Scenario:**
```bash
# Attacker has access to Docker daemon
docker run -it --rm -v /:/host alpine sh

# Inside container:
chroot /host
# Now has full host filesystem access
# Can read:
# - /etc/shadow (password hashes)
# - /root/.ssh/id_rsa (SSH keys)
# - /run/secrets (application secrets)
# - Any file on host system
```

**Why This Works:**
- Docker daemon runs as root on host
- Volume mounts bypass container isolation
- Even non-root containers can read mounted files
- OS-level whitelisting doesn't prevent this
- User 1001 inside container can still read host files

**Impact:**
- Complete host compromise
- Secret theft
- Lateral movement
- Bypass restricted bash (rbash)
- Modify system files

---

## Defense-in-Depth Strategy

Security is achieved through multiple overlapping layers. If one layer fails, others provide protection.

```
┌─────────────────────────────────────────────────┐
│ Layer 10: Incident Response & Forensics        │
├─────────────────────────────────────────────────┤
│ Layer 9: Monitoring & Audit Logging            │
├─────────────────────────────────────────────────┤
│ Layer 8: Network Policies & Segmentation       │
├─────────────────────────────────────────────────┤
│ Layer 7: Secret Isolation (/run/secrets)       │
├─────────────────────────────────────────────────┤
│ Layer 6: RBAC & Access Control                 │
├─────────────────────────────────────────────────┤
│ Layer 5: Admission Controllers & Policies      │
├─────────────────────────────────────────────────┤
│ Layer 4: Container Runtime Security            │
├─────────────────────────────────────────────────┤
│ Layer 3: Image Security & Scanning             │
├─────────────────────────────────────────────────┤
│ Layer 2: CI/CD Automation & GitOps             │
├─────────────────────────────────────────────────┤
│ Layer 1: Organizational (Separation of Duties) │
└─────────────────────────────────────────────────┘
```

### Layer 1: Organizational
**Principle:** Developers should never access production infrastructure

```
Developers → Code → Git → CI/CD → Platform Team → Production
     ❌                                   ✅
  No SSH Access                    Full Access
  No Docker Access                 (with MFA + Audit)
  No kubectl Access
```

### Layer 2: CI/CD Automation
**Principle:** No manual deployments, everything automated

- Git is source of truth
- Automated builds from standardized base images
- Security scanning in pipeline
- Image signing and verification
- GitOps deployment (ArgoCD/FluxCD)

### Layer 3: Image Security
**Principle:** Secure images by default

- Standardized base images with USER 1001
- No secrets in images
- Regular vulnerability scanning
- Minimal attack surface (distroless preferred)
- Signed images (Cosign)

### Layer 4: Container Runtime Security
**Principle:** Restrict container capabilities

- Non-root user (USER 1001)
- Read-only root filesystem
- No privilege escalation
- Drop all capabilities
- No host namespaces (network, PID, IPC)

### Layer 5: Admission Controllers
**Principle:** Enforce policies at admission time

- Block hostPath volumes
- Block privileged containers
- Enforce resource limits
- Validate security contexts
- Pod Security Standards (restricted)

### Layer 6: RBAC
**Principle:** Least privilege access

- Developers: Read-only access to logs
- CI/CD: Limited to specific namespaces
- Platform Team: Full access with audit
- No shared credentials

### Layer 7: Secret Isolation
**Principle:** Secrets never in environment variables

- Mount secrets as volumes at /run/secrets
- Read-only mount
- File permissions 0400
- No `docker inspect` visibility
- Automatic rotation

### Layer 8: Network Policies
**Principle:** Zero-trust networking

- Default deny all traffic
- Explicit allow rules only
- No access to host network
- Service mesh with mTLS (optional)

### Layer 9: Monitoring & Logging
**Principle:** Detect and alert on anomalies

- Centralized logging (ELK, Loki)
- Audit all API calls
- Alert on:
  - Privileged container attempts
  - Host volume mount attempts
  - Failed authentication
  - Unusual network activity
  - Secret access patterns

### Layer 10: Incident Response
**Principle:** Prepare for breaches

- Automated secret rotation on detection
- Container image quarantine
- Forensics collection
- Post-incident reviews

---

## Threat Models

### Threat 1: Compromised Developer Laptop
**Attack:** Stolen credentials from developer's machine

**Mitigations:**
- ✅ No production access from developer machines
- ✅ CI/CD has limited, time-bound tokens
- ✅ MFA required for any production access
- ✅ Short-lived credentials (Vault dynamic secrets)

### Threat 2: Malicious Insider
**Attack:** Developer with Docker access mounts host filesystem

**Mitigations:**
- ✅ Admission controllers block hostPath volumes
- ✅ RBAC prevents pod creation
- ✅ Audit logging tracks all attempts
- ✅ Separation of duties (devs can't deploy)

### Threat 3: Container Breakout
**Attack:** Exploit in container runtime allows host access

**Mitigations:**
- ✅ Non-root user limits damage
- ✅ Read-only filesystem prevents persistence
- ✅ Dropped capabilities reduce attack surface
- ✅ AppArmor/SELinux profiles restrict syscalls
- ✅ Seccomp profiles block dangerous system calls

### Threat 4: Secret Exposure in Git
**Attack:** Secrets accidentally committed to repository

**Mitigations:**
- ✅ GitHub Secret Scanning with push protection
- ✅ Pre-commit hooks (detect-secrets, gitleaks)
- ✅ Never store secrets in code
- ✅ Use secret references, not values
- ✅ SOPS/Sealed Secrets for encrypted storage

### Threat 5: Supply Chain Attack
**Attack:** Compromised base image or dependency

**Mitigations:**
- ✅ Use trusted base images only
- ✅ Image scanning (Trivy, Grype)
- ✅ SBOM generation
- ✅ Image signing and verification
- ✅ Private registry with access controls

### Threat 6: Privileged Container Abuse
**Attack:** Running container with --privileged flag

**Mitigations:**
- ✅ Pod Security Standards enforce restrictions
- ✅ Admission controllers reject privileged pods
- ✅ RBAC prevents privileged creation
- ✅ Audit alerts on attempts

---

## Industry Best Practices

### Google
- **Secret Manager:** Centralized secrets with KMS encryption
- **Regional Secrets:** Data residency compliance
- **Berglas:** Open-source secret management
- **GKE Security:** Workload identity, binary authorization

### Meta
- **Privacy Aware Infrastructure (PAI):** Purpose limitation
- **FBCrypto:** Managed cryptographic library
- **MFA Everywhere:** All network access requires MFA
- **Lesson Learned:** Never store passwords in plaintext ($101.5M fine)

### Amazon
- **AWS Secrets Manager:** Automatic rotation via Lambda
- **VPC Endpoints:** Private network access only
- **Hierarchical Naming:** Organize secrets at scale
- **IaC Integration:** Terraform/CloudFormation native support

### GitHub
- **Secret Scanning:** 39M secrets detected in 2024
- **Push Protection:** Block commits with secrets
- **AI Detection:** Copilot for unstructured secrets
- **Partner Program:** Auto-revocation with 100+ providers

### HashiCorp Vault
- **Dynamic Secrets:** Short-lived, auto-generated credentials
- **Zero-Trust:** Never trust, always verify
- **Centralized Management:** Single source of truth
- **Audit Logging:** Complete access trail

---

## Key Principles

### 1. Never Trust, Always Verify
- Authenticate and authorize every request
- Even internal traffic requires verification
- Time-bound access tokens
- Regular access reviews

### 2. Principle of Least Privilege
- Grant minimum permissions required
- Temporary elevation only when needed
- Audit all privilege usage
- Regular permission audits

### 3. Defense in Depth
- Multiple overlapping security layers
- Assume each layer can be breached
- Each layer independent of others
- Comprehensive monitoring

### 4. Fail Securely
- Default deny policies
- Fail closed, not open
- Graceful degradation
- Clear error messages (without leaking info)

### 5. Separation of Duties
- No single person has complete access
- Code review required
- Dual control for critical operations
- Audit trail for all actions

### 6. Automate Everything
- No manual secret handling
- Automated rotation
- Automated deployments
- Automated security scanning

### 7. Encrypt Everything
- At rest: KMS/HSM encryption
- In transit: TLS 1.3 minimum
- End-to-end encryption
- Key rotation

### 8. Monitor and Audit
- Log all access
- Real-time alerting
- Regular log reviews
- Compliance reporting

### 9. Plan for Breaches
- Assume breach will happen
- Incident response plan
- Regular drills
- Post-mortem reviews

### 10. Security is Everyone's Responsibility
- Security training for all
- Secure defaults
- Easy to do the right thing
- Hard to do the wrong thing

---

## References

- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [Google Secret Manager](https://cloud.google.com/secret-manager/docs/best-practices)
- [GitHub Advanced Security](https://github.blog/security/application-security/next-evolution-github-advanced-security/)
- [HashiCorp Vault](https://developer.hashicorp.com/vault/tutorials)
- [CNCF Security Best Practices](https://www.cncf.io/blog/2024/01/25/kubernetes-security-best-practices/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

---

## Next Steps

1. Read [Secret Management Guide](./02-SECRET-MANAGEMENT.md)
2. Review [Container Security Guide](./03-CONTAINER-SECURITY.md)
3. Study [Attack Scenarios](./04-ATTACK-SCENARIOS.md)
4. Implement [POC Examples](../README.md)
