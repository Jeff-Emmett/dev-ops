FROM mcr.microsoft.com/playwright:v1.50.0-noble

WORKDIR /app

# Python + PyYAML for runner/alerts
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip python3-yaml && \
    rm -rf /var/lib/apt/lists/*

# Install Playwright dependencies (Chromium only)
COPY package.json package-lock.json ./
RUN npm ci && npx playwright install --with-deps chromium

# Copy test suite
COPY . .

ENTRYPOINT ["python3", "runner.py"]
