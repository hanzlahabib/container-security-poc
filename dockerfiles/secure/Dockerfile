# ✅ SECURE DOCKERFILE - PRODUCTION READY
# This demonstrates security best practices

# ✅ Use specific version tag (predictable, reproducible)
# ✅ Use minimal base image (smaller attack surface)
FROM node:18-alpine3.18

# ✅ Install security updates
RUN apk update && apk upgrade

# ✅ Install only necessary dependencies
RUN apk add --no-cache \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# ✅ Create non-root user with specific UID/GID
RUN addgroup -g 1001 -S appuser && \
    adduser -u 1001 -S appuser -G appuser

# ✅ Create necessary directories with proper permissions
RUN mkdir -p /app /run/secrets && \
    chown -R appuser:appuser /app /run/secrets && \
    chmod 700 /run/secrets

WORKDIR /app

# ✅ Copy application code as non-root user
COPY --chown=appuser:appuser package.json ./
COPY --chown=appuser:appuser server.js ./
COPY --chown=appuser:appuser healthcheck.js ./

# ✅ Switch to non-root user
USER appuser

# ✅ NO secrets in image (read from /run/secrets at runtime)
# Secrets will be mounted as volumes

# ✅ Use non-root user for runtime
USER appuser

# ✅ Expose only necessary port
EXPOSE 8080

# ✅ Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

# ✅ Use exec form (proper signal handling)
# ✅ Run as non-root
CMD ["node", "server.js"]
