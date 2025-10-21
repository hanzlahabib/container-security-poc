# ❌ INSECURE DOCKERFILE - DO NOT USE IN PRODUCTION
# This demonstrates common security anti-patterns

FROM ubuntu:latest

# ❌ Running as root (default)
# ❌ Using latest tag (unpredictable)

# ❌ Hardcoded secrets in environment variables
ENV DATABASE_PASSWORD=SuperSecret123
ENV API_KEY=sk-1234567890abcdef
ENV AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# ❌ Installing unnecessary packages (large attack surface)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    vim \
    sudo \
    ssh \
    telnet \
    netcat \
    gcc \
    make \
    && rm -rf /var/lib/apt/lists/*

# ❌ No integrity verification
RUN wget https://example.com/app.tar.gz && tar xzf app.tar.gz

# ❌ Secrets in files (will be in image layers)
COPY .env /app/.env
COPY config/database.yml /app/config/database.yml

WORKDIR /app

# ❌ Running application as root
# ❌ No health checks
# ❌ No resource limits

EXPOSE 8080

CMD ["/app/server"]
