FROM mcr.microsoft.com/playwright:v1.42.1-focal

WORKDIR /tests

# Copy package files
COPY package*.json ./

# Install dependencies and Playwright browsers
RUN npm ci && \
    npx playwright install --with-deps chromium

# Copy test files
COPY playwright.config.js ./
COPY tests ./tests/

# Set default environment variable
ENV DASHBOARD_URL=https://dashboard.local.dev

# Command to run tests
ENTRYPOINT ["npm", "run", "test"]
