# --- STAGE 1: Server build ---
FROM node:22-alpine AS server

RUN apk add --no-cache build-base python3

WORKDIR /app
COPY server .

# Kein npm-global-update nötig!
RUN npm install \
  && npm run build \
  && npm prune --production

# --- STAGE 2: Client build ---
FROM node:22 AS client

WORKDIR /app
COPY client .

# --omit=dev reicht hier völlig aus
RUN npm install --omit=dev \
  && INDEX_FORMAT=ejs DISABLE_ESLINT_PLUGIN=true npm run build

# --- STAGE 3: Final image ---
FROM node:22-alpine

# Installiere System-Pakete (bash, python, squid)
RUN apk add --no-cache bash python3 squid

WORKDIR /app

# Lizenzen kopieren
COPY LICENSE.md .
COPY ["LICENSES/PLANKA Community License DE.md", "LICENSE_DE.md"]

# Gebauten Server und Client kopieren
COPY --from=server /app/node_modules node_modules
COPY --from=server /app/dist .
COPY --from=client /app/dist public

# Wichtig: Diese Operationen VOR dem Wechsel zum User 'node' machen
RUN mv .env.sample .env \
  && mv public/index.ejs views || true \
  && npm config set update-notifier false

# Falls ein start.sh existiert, muss es ausführbar sein
RUN chmod +x start.sh || true

EXPOSE 1337

# Wechsel zum sicheren User 'node'
USER node

# Healthcheck & Start
HEALTHCHECK --interval=10s --timeout=2s --start-period=15s \
  CMD node ./healthcheck.js

CMD ["./start.sh"]
