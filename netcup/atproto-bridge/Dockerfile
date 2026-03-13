FROM oven/bun:1-slim AS base

WORKDIR /app

# Install dependencies
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile 2>/dev/null || bun install

# Copy source
COPY server/ ./server/
COPY lexicons/ ./lexicons/
COPY tsconfig.json ./

# Create data directory
RUN mkdir -p /data

EXPOSE 3001

CMD ["bun", "run", "server/index.ts"]
