#!/bin/sh
# Map Railway's PORT env var to N8N_PORT at runtime
export N8N_PORT="${PORT:-5678}"
exec n8n start
