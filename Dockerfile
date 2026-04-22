# Stage 1: Server build
FROM node:22-alpine AS server
RUN apk add --no-cache build-base python3
WORKDIR /app
COPY server .
RUN npm install && npm run build && npm prune --production

# Stage 2: Client build
FROM node:22 AS client
WORKDIR /app
COPY client .
# Hier habe ich "npm install npm --global" entfernt:
RUN npm install --omit=dev \
  && INDEX_FORMAT=ejs DISABLE_ESLINT_PLUGIN=true npm run build

# Stage 3: Final image
FROM node:22-alpine
# Hier habe ich "npm install npm --global" ebenfalls entfernt:
RUN apk add --no-cache bash python3 squid
WORKDIR /app

COPY --from=server /app/node_modules node_modules
COPY --from=server /app/dist .
COPY --from=client /app/dist public

# Restliche Einrichtung
RUN mv .env.sample .env || true \
  && mv public/index.ejs views || true \
  && npm config set update-notifier false

EXPOSE 1337
CMD ["./start.sh"]
