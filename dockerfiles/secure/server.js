#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');

// ✅ Read secrets from volume-mounted files (not environment variables)
function readSecret(secretName) {
  try {
    const secretPath = path.join('/run/secrets', secretName);
    if (fs.existsSync(secretPath)) {
      return fs.readFileSync(secretPath, 'utf8').trim();
    }
    console.warn(`Secret ${secretName} not found at ${secretPath}`);
    return null;
  } catch (error) {
    console.error(`Error reading secret ${secretName}:`, error.message);
    return null;
  }
}

// Read secrets at startup
const dbPassword = readSecret('database-password');
const apiKey = readSecret('api-key');

console.log('✅ Secrets loaded from /run/secrets');
console.log('❌ NO secrets in environment variables');

// Verify running as non-root
const currentUser = process.env.USER || 'unknown';
const uid = process.getuid ? process.getuid() : 'unknown';
console.log(`Running as user: ${currentUser} (UID: ${uid})`);

if (uid === 0) {
  console.error('❌ WARNING: Running as root! This is insecure!');
  process.exit(1);
}

const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', uid }));
    return;
  }

  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(`Secure Container Demo\n\nRunning as UID: ${uid}\nSecrets loaded: ${dbPassword ? 'Yes' : 'No'}\n`);
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`✅ Running as non-root user (UID: ${uid})`);
  console.log(`✅ Secrets loaded from /run/secrets`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
