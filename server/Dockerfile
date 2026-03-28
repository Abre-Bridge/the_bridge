FROM node:20-slim

WORKDIR /app

# Install build dependencies for native modules (argon2, mediasoup fallback)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

# Create logs directory
RUN mkdir -p logs

EXPOSE 3000

CMD ["node", "src/index.js"]
