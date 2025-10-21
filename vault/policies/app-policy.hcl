# Vault Policy for Application Access
# Principle of Least Privilege - only read access to app secrets

# Allow reading secrets for this specific app
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Allow reading database credentials (dynamic secrets)
path "database/creds/myapp-role" {
  capabilities = ["read"]
}

# Deny all other paths
path "secret/data/admin/*" {
  capabilities = ["deny"]
}

path "secret/data/other-app/*" {
  capabilities = ["deny"]
}

# Allow token self-renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow token self-lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
