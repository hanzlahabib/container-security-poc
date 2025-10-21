#!/bin/bash
# Security Testing Script
# Validates security configurations are properly enforced

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

echo "🔒 Security Configuration Tests"
echo "================================"
echo ""

# Test 1: Pod Security Standards
echo "Test 1: Checking Pod Security Standards..."
if kubectl get ns secure-app -o json | jq -e '.metadata.labels["pod-security.kubernetes.io/enforce"] == "restricted"' >/dev/null 2>&1; then
    pass "Namespace has restricted Pod Security Standard"
else
    fail "Namespace missing restricted Pod Security Standard"
fi

# Test 2: RBAC - Developers can't create pods
echo ""
echo "Test 2: Checking RBAC restrictions..."
if kubectl auth can-i create pods --as=system:serviceaccount:default:developer -n secure-app 2>/dev/null | grep -q "no"; then
    pass "Developers cannot create pods"
else
    fail "Developers can create pods (security risk!)"
fi

# Test 3: Try to create pod with hostPath (should fail)
echo ""
echo "Test 3: Testing hostPath volume blocking..."
cat > /tmp/bad-pod.yaml <<EOF
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

if kubectl apply -f /tmp/bad-pod.yaml 2>&1 | grep -q "forbidden\|denied"; then
    pass "hostPath volumes are blocked"
else
    fail "hostPath volumes are NOT blocked (critical vulnerability!)"
fi
rm -f /tmp/bad-pod.yaml

# Test 4: Try to create privileged pod (should fail)
echo ""
echo "Test 4: Testing privileged container blocking..."
cat > /tmp/privileged-pod.yaml <<EOF
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

if kubectl apply -f /tmp/privileged-pod.yaml 2>&1 | grep -q "forbidden\|denied"; then
    pass "Privileged containers are blocked"
else
    fail "Privileged containers are NOT blocked (critical vulnerability!)"
fi
rm -f /tmp/privileged-pod.yaml

# Test 5: Try to create root container (should fail)
echo ""
echo "Test 5: Testing root user blocking..."
cat > /tmp/root-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: root-pod
  namespace: secure-app
spec:
  containers:
  - name: app
    image: alpine
    securityContext:
      runAsUser: 0
EOF

if kubectl apply -f /tmp/root-pod.yaml 2>&1 | grep -q "forbidden\|denied\|must not set runAsUser to 0"; then
    pass "Root containers are blocked"
else
    fail "Root containers are NOT blocked"
fi
rm -f /tmp/root-pod.yaml

# Test 6: Check existing deployments run as non-root
echo ""
echo "Test 6: Checking existing deployments run as non-root..."
if kubectl get pods -n secure-app -o json 2>/dev/null | jq -e '.items[].spec.securityContext.runAsNonRoot == true' >/dev/null 2>&1; then
    pass "Deployments configured to run as non-root"
else
    warn "No deployments found or not configured for non-root"
fi

# Test 7: Check secrets are not exposed via env vars
echo ""
echo "Test 7: Checking secrets are volume-mounted (not env vars)..."
ENV_SECRET_COUNT=$(kubectl get pods -n secure-app -o json 2>/dev/null | \
    jq '[.items[].spec.containers[].env[]? | select(.valueFrom.secretKeyRef)] | length' || echo "0")

if [ "$ENV_SECRET_COUNT" -eq "0" ]; then
    pass "No secrets exposed via environment variables"
else
    fail "Found $ENV_SECRET_COUNT secrets in environment variables"
fi

# Test 8: Check Network Policies exist
echo ""
echo "Test 8: Checking Network Policies..."
if kubectl get networkpolicy -n secure-app default-deny-all >/dev/null 2>&1; then
    pass "Default deny-all Network Policy exists"
else
    fail "Default deny-all Network Policy missing"
fi

# Test 9: Check for Gatekeeper/OPA policies
echo ""
echo "Test 9: Checking admission control policies..."
if kubectl get constrainttemplates >/dev/null 2>&1; then
    POLICY_COUNT=$(kubectl get constrainttemplates --no-headers 2>/dev/null | wc -l)
    if [ "$POLICY_COUNT" -gt "0" ]; then
        pass "Gatekeeper policies are installed ($POLICY_COUNT policies)"
    else
        warn "Gatekeeper installed but no policies found"
    fi
else
    warn "Gatekeeper/OPA not installed"
fi

# Test 10: Check Vault is accessible
echo ""
echo "Test 10: Checking Vault connectivity..."
if kubectl get pods -n vault -l app.kubernetes.io/name=vault 2>/dev/null | grep -q Running; then
    pass "Vault pods are running"
else
    warn "Vault not found or not running"
fi

# Test 11: Check External Secrets Operator
echo ""
echo "Test 11: Checking External Secrets Operator..."
if kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
    pass "External Secrets Operator is installed"
else
    warn "External Secrets Operator not installed"
fi

# Test 12: Docker/Containerd security
echo ""
echo "Test 12: Checking container runtime security..."
if command -v docker >/dev/null 2>&1; then
    if docker info 2>/dev/null | grep -q "userns"; then
        pass "Docker user namespace remapping enabled"
    else
        warn "Docker user namespace remapping not enabled"
    fi
fi

# Summary
echo ""
echo "================================"
echo "SECURITY TEST SUMMARY"
echo "================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ Security tests FAILED. Please fix critical issues.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All security tests PASSED!${NC}"
    exit 0
fi
