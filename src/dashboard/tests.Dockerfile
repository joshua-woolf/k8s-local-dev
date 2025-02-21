FROM mcr.microsoft.com/playwright:v1.42.1-focal

WORKDIR /tests

COPY package*.json ./

RUN npm ci && \
    npx playwright install --with-deps chromium

COPY playwright.config.js ./
COPY tests ./tests/

ENV DASHBOARD_URL=https://dashboard.local.dev

ENTRYPOINT ["npm", "run", "test"]
