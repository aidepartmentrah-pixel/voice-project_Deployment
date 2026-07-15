# node-backend/Dockerfile
# Must be built with the REPO ROOT as build context (not node-backend/ itself)
# because server.js serves ../frontend as static files — see docker-compose.yml
# (`context: .`, `dockerfile: node-backend/Dockerfile`).

FROM node:22-slim

WORKDIR /app/node-backend

COPY node-backend/package.json node-backend/package-lock.json ./
RUN npm ci --omit=dev

COPY node-backend/ ./
# frontend/ is one directory up from node-backend/ on disk, matching the
# express.static(path.join(__dirname, "../frontend")) path in server.js.
COPY frontend/ ../frontend/

RUN mkdir -p uploads/excel \
    && useradd --create-home --shell /bin/false appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 3000

CMD ["node", "server.js"]
