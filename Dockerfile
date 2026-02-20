FROM n8nio/n8n

# Ensure n8n listens on all interfaces
ENV N8N_LISTEN_ADDRESS=0.0.0.0

# Copy workflows into the container for easy access
COPY workflows/ /home/node/workflows/

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Railway injects PORT at runtime — entrypoint maps it to N8N_PORT
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
