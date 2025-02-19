const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 30000,
  expect: {
    timeout: 5000
  },
  use: {
    baseURL: 'https://dashboard.local.dev',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  reporter: [
    ['list'],
  ]
});
