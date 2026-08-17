FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY server/package.json server/package-lock.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY server/ .

ENV PORT=8080
EXPOSE 8080

CMD ["node", "hogarquest_server.js"]