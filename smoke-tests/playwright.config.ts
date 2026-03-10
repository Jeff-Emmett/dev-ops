import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  retries: 1,
  reporter: [
    ['json', { outputFile: '/tmp/smoke-results.json' }],
    ['list'],
  ],
  use: {
    ignoreHTTPSErrors: true,
    screenshot: 'only-on-failure',
    trace: 'off',
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});
