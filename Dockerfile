FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY api ./api
COPY simulator ./simulator
EXPOSE 3000
CMD ["node", "api/server.js"]
