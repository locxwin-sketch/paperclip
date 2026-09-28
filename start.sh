#!/bin/sh
set -e

: "${DATABASE_URL:?DATABASE_URL is not set - add a Postgres service and reference it}"

mkdir -p /paperclip/instances/default/logs
chown -R node:node /paperclip

CONFIG_PATH="/paperclip/instances/default/config.json"
if true; then
  PUBLIC_URL="${PAPERCLIP_PUBLIC_URL:-http://localhost:3100}"
  cat > "$CONFIG_PATH" <<CONF
{
  "\$meta": { "version": 1, "updatedAt": "2026-01-01T00:00:00Z", "source": "onboard" },
  "database": { "mode": "postgres", "backup": { "enabled": true, "intervalMinutes": 60, "retentionDays": 7, "dir": "/paperclip/instances/default/data/backups" } },
  "logging": { "mode": "file", "logDir": "/paperclip/instances/default/logs" },
  "server": { "deploymentMode": "authenticated", "exposure": "public", "bind": "lan", "host": "0.0.0.0", "port": ${PORT:-3100}, "serveUi": true },
  "auth": { "baseUrlMode": "explicit", "publicBaseUrl": "${PUBLIC_URL}", "disableSignUp": false },
  "storage": { "provider": "local_disk", "localDisk": { "baseDir": "/paperclip/instances/default/data/storage" } },
  "secrets": { "provider": "local_encrypted", "strictMode": false, "localEncrypted": { "keyFilePath": "/paperclip/instances/default/secrets/master.key" } },
  "telemetry": { "enabled": false }
}
CONF
  chown node:node "$CONFIG_PATH"
fi

gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js &
SERVER_PID=$!

until wget -qO /dev/null http://localhost:${PORT:-3100}/api/health 2>/dev/null; do
  kill -0 $SERVER_PID 2>/dev/null || { echo "Server exited during startup"; exit 1; }
  sleep 2
done

gosu node node --import ./server/node_modules/tsx/dist/loader.mjs -e "
import { bootstrapCeoInvite } from './cli/src/commands/auth-bootstrap-ceo.js';
bootstrapCeoInvite({ expiresHours: 72 }).catch(e => console.error('Bootstrap error:', e.message));
" 2>&1 || echo "Bootstrap script completed"

wait $SERVER_PID
