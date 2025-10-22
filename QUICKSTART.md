# Quick Start - Team Demo Guide

**Repository:** https://github.com/hanzlahabib/container-security-demo

---

## 🚀 One-Command Demos

### For Team Presentation (5 minutes)
```bash
make present
```
**Shows:** Insecure vs Secure containers, side-by-side comparison, complete demo

### Quick Demo (2 minutes)
```bash
make quick-demo
```
**Shows:** Fast comparison without rebuilding images

### Just Show the Summary
```bash
make summary
```
**Shows:** Quick comparison table of insecure vs secure

---

## 🎯 Essential Commands

```bash
make help              # Show all available commands
make demo-all          # Complete security demo (5 min)
make compare           # Side-by-side insecure vs secure
make attack-all        # Run attack scenarios (PDO incident)
make clean             # Clean up everything
```

---

## 📊 Step-by-Step Demo

### 1. Show Insecure Container Problems
```bash
make test-insecure
```
**Demonstrates:**
- ❌ Running as root (UID 0)
- ❌ Secrets stolen from environment
- ❌ Secrets visible in `docker inspect`

### 2. Show Secure Container Solution
```bash
make test-secure
```
**Demonstrates:**
- ✅ Running as UID 1001 (non-root)
- ✅ No secrets in environment
- ✅ Secrets protected from `docker inspect`
- ✅ App can still read secrets from files

### 3. Show Attack Scenarios
```bash
make attack-volume     # PDO incident (volume mount attack)
make attack-secrets    # Secret exposure demo
```

---

## 🎥 For Screen Sharing

### Show Summary First
```bash
make summary
```
Copy the output to show your team!

### Then Run Full Demo
```bash
make present
```

---

## 📖 Documentation Commands

```bash
make docs              # Open README
make testing-guide     # Show testing guide
make show-attacks      # Show attack documentation
```

---

## 🧹 Cleanup

```bash
make clean             # Remove containers
make clean-images      # Remove containers + images
```

---

## 💡 What Each Demo Proves

| Command | Time | What It Shows |
|---------|------|---------------|
| `make test-insecure` | 1 min | How secrets leak from env vars |
| `make test-secure` | 1 min | How volume-mounted secrets are protected |
| `make attack-volume` | 2 min | PDO incident - volume mount escalation |
| `make attack-secrets` | 2 min | 3 ways to steal env var secrets |
| `make compare` | 2 min | Side-by-side comparison |
| `make present` | 5 min | Complete team presentation |

---

## 🎯 Recommended Flow for Team Demo

```bash
# 1. Clean start
make clean

# 2. Show the problem (insecure)
make test-insecure

# 3. Show the solution (secure)
make test-secure

# 4. Show summary comparison
make summary

# 5. (Optional) Run attack scenarios
make attack-all
```

**Total time:** ~5 minutes

---

## 📝 Quick Reference

### Most Used Commands
```bash
make help              # List all commands
make present           # Full 5-min demo
make quick-demo        # Fast 2-min demo
make compare           # Side-by-side comparison
make summary           # Show comparison table
make clean             # Clean up
```

### For Deep Dive
```bash
make attack-volume     # PDO incident demo
make attack-secrets    # Secret exposure demo
make testing-guide     # Full testing docs
```

---

## 🔗 Links

- **GitHub:** https://github.com/hanzlahabib/container-security-demo
- **Full Docs:** `README.md`
- **Testing Guide:** `TESTING-GUIDE.md`
- **Setup Guide:** `SETUP.md`
- **Security Overview:** `docs/01-SECURITY-OVERVIEW.md`

---

## 🎓 Key Takeaways for Team

1. **Environment variables leak secrets** → Anyone with `docker inspect` can steal them
2. **Root containers = full system access** → Always run as non-root
3. **Volume-mounted secrets are protected** → Not visible in `docker inspect`
4. **Defense-in-depth works** → Multiple layers of security

---

## ⚡ One-Liner for Quick Demo

```bash
make present && echo "Demo complete! Questions?"
```

---

**Need help?** Run `make help` or check `TESTING-GUIDE.md`
