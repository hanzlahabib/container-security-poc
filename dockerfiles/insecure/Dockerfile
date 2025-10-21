# ❌ INSECURE DOCKERFILE - DO NOT USE IN PRODUCTION
# This demonstrates common security anti-patterns

FROM ubuntu:latest

# ❌ Running as root (default)
# ❌ Using latest tag (unpredictable)

# ❌ Hardcoded secrets in environment variables
ENV DATABASE_PASSWORD=SuperSecret123
ENV API_KEY=sk-1234567890abcdef
ENV AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
ENV DATABASE_HOST=db.internal.com
ENV DATABASE_PORT=5432
ENV DATABASE_USER=admin

# ❌ Installing unnecessary packages (large attack surface)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ❌ Create app directory
RUN mkdir -p /app

WORKDIR /app

# ❌ Create a simple script that shows secrets
RUN echo '#!/bin/bash' > /app/server.sh && \
    echo 'echo "=== INSECURE SERVER STARTING ==="' >> /app/server.sh && \
    echo 'echo "Running as: $(whoami) (UID: $(id -u))"' >> /app/server.sh && \
    echo 'echo "Database Password: $DATABASE_PASSWORD"' >> /app/server.sh && \
    echo 'echo "API Key: $API_KEY"' >> /app/server.sh && \
    echo 'echo "AWS Secret: $AWS_SECRET_KEY"' >> /app/server.sh && \
    echo 'echo "================================"' >> /app/server.sh && \
    echo 'echo "These secrets are visible in:"' >> /app/server.sh && \
    echo 'echo "1. docker inspect"' >> /app/server.sh && \
    echo 'echo "2. docker exec env"' >> /app/server.sh && \
    echo 'echo "3. /proc/1/environ"' >> /app/server.sh && \
    echo 'echo "================================"' >> /app/server.sh && \
    echo 'sleep infinity' >> /app/server.sh && \
    chmod +x /app/server.sh

# ❌ Running application as root
# ❌ No health checks
# ❌ No resource limits
# ❌ No security context

EXPOSE 8080

CMD ["/app/server.sh"]
