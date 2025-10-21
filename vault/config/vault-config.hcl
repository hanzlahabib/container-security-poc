# Vault Server Configuration for On-Premises Deployment

# Storage backend - Integrated Raft for HA
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-0"

  # For HA cluster, configure retry_join
  retry_join {
    leader_api_addr = "http://vault-1:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-2:8200"
  }
}

# TCP listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false  # Enable TLS in production!
  tls_cert_file = "/vault/tls/tls.crt"
  tls_key_file  = "/vault/tls/tls.key"
}

# API address
api_addr = "http://vault-0:8200"

# Cluster address
cluster_addr = "https://vault-0:8201"

# UI
ui = true

# Telemetry (optional - for monitoring)
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

# Seal configuration
# For production, use auto-unseal with HSM or cloud KMS
# seal "pkcs11" {
#   lib = "/usr/lib/libckcs11.so"
#   slot = "0"
#   pin = "AAAA-BBBB-CCCC-DDDD"
#   key_label = "vault-hsm-key"
# }

# Default seal (Shamir) - requires manual unseal
# In production, use auto-unseal with HSM
