FROM n8nio/n8n

# Railway injects PORT env var — n8n needs N8N_PORT to bind to it
ENV N8N_PORT=${PORT:-5678}

# Ensure n8n listens on all interfaces
ENV N8N_LISTEN_ADDRESS=0.0.0.0

# Copy workflows into the container for easy access
COPY workflows/ /home/node/workflows/

# Use shell form so $PORT is resolved at runtime
CMD n8n start --tunnel
