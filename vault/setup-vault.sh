#!/bin/bash
# Vault Setup Script for On-Premises Deployment

set -e

echo "🚀 Setting up HashiCorp Vault..."

# Deploy Vault using Helm
echo "📦 Installing Vault via Helm..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3 \
  --set server.ha.raft.enabled=true \
  --set ui.enabled=true

echo "⏳ Waiting for Vault pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Initialize Vault (only on first install)
echo "🔐 Initializing Vault..."
kubectl exec vault-0 -n vault -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

echo "⚠️  IMPORTANT: Save vault-keys.json securely!"
echo "⚠️  This file contains your unseal keys and root token!"

# Extract unseal keys
UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' vault-keys.json)
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' vault-keys.json)
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' vault-keys.json)
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)

# Unseal all Vault instances
echo "🔓 Unsealing Vault instances..."
for i in 0 1 2; do
  echo "Unsealing vault-$i..."
  kubectl exec vault-$i -n vault -- vault operator unseal "$UNSEAL_KEY_1"
  kubectl exec vault-$i -n vault -- vault operator unseal "$UNSEAL_KEY_2"
  kubectl exec vault-$i -n vault -- vault operator unseal "$UNSEAL_KEY_3"
done

# Login with root token
export VAULT_ADDR='http://localhost:8200'
kubectl port-forward -n vault vault-0 8200:8200 &
PORT_FORWARD_PID=$!
sleep 5

vault login "$ROOT_TOKEN"

# Enable KV secrets engine
echo "📝 Enabling KV secrets engine..."
vault secrets enable -path=secret kv-v2

# Create sample secrets
echo "🔑 Creating sample secrets..."
vault kv put secret/myapp/database \
  username=dbuser \
  password=SuperSecret123 \
  host=postgres.internal \
  port=5432

vault kv put secret/myapp/api \
  key=sk-1234567890abcdef \
  endpoint=https://api.example.com

# Enable Kubernetes auth
echo "🔐 Enabling Kubernetes authentication..."
vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create policy for app
echo "📋 Creating Vault policy..."
vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
EOF

# Create Kubernetes auth role
echo "🎭 Creating Kubernetes auth role..."
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=secure-app-sa \
  bound_service_account_namespaces=secure-app \
  policies=myapp-policy \
  ttl=1h

# Enable database secrets engine for dynamic credentials
echo "💾 Enabling database secrets engine..."
vault secrets enable database

vault write database/config/mydb \
  plugin_name=postgresql-database-plugin \
  allowed_roles="myapp-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb?sslmode=disable" \
  username="vault" \
  password="vault-password"

vault write database/roles/myapp-role \
  db_name=mydb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Enable audit logging
echo "📊 Enabling audit logging..."
vault audit enable file file_path=/vault/logs/audit.log

# Kill port-forward
kill $PORT_FORWARD_PID

echo "✅ Vault setup complete!"
echo ""
echo "🔑 Root Token: $ROOT_TOKEN"
echo "🔓 Unseal Keys: See vault-keys.json"
echo ""
echo "⚠️  CRITICAL: Store vault-keys.json in a secure location!"
echo "⚠️  CRITICAL: Delete vault-keys.json from this server after backup!"
echo ""
echo "📖 Next steps:"
echo "  1. Install External Secrets Operator: ./setup-external-secrets.sh"
echo "  2. Deploy application: kubectl apply -f kubernetes/manifests/"
