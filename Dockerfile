FROM node:22-alpine

WORKDIR /app

# App source. This project is zero-dependency (Node built-ins only), so there
# is nothing to install — just copy the code in.
COPY server.js ./
COPY public ./public

# Pre-create the data dir owned by the runtime user. When a fresh named volume
# is mounted here, Docker seeds it from this mountpoint, so it inherits writable
# ownership — otherwise the volume is root-owned and the app can't persist.
RUN mkdir -p /app/data && chown -R node:node /app/data

# PORT matches the app default too, but is set explicitly so EXPOSE/HEALTHCHECK
# and the running process can't drift apart. HOST defaults to 0.0.0.0 in the app.
ENV PORT=9000 \
    DATA_FILE=/app/data/items.json \
    TOKEN_FILE=/app/data/token.json

EXPOSE 9000
USER node
VOLUME ["/app/data"]

# Cheap liveness check against the public items endpoint.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:9000/api/items >/dev/null 2>&1 || exit 1

CMD ["node", "server.js"]
