import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'yaml';

interface PageConfig {
  path: string;
  expect_text?: string;
  expect_selector?: string;
}

interface SiteConfig {
  url: string;
  spa?: boolean;
  pages: PageConfig[];
}

interface SitesConfig {
  defaults: { wait_after_deploy: number };
  sites: Record<string, SiteConfig>;
}

// Load sites config
const configPath = path.resolve(__dirname, '..', 'sites.yaml');
const config: SitesConfig = yaml.parse(fs.readFileSync(configPath, 'utf-8'));

// Filter sites based on SMOKE_SITE env var (set by runner.py)
const targetSite = process.env.SMOKE_SITE;
const sites = targetSite
  ? { [targetSite]: config.sites[targetSite] }
  : config.sites;

// JS error patterns to ignore (third-party noise, CSP, etc.)
const IGNORED_ERROR_PATTERNS = [
  /favicon/i,
  /third-party cookie/i,
  /net::ERR_/,
  /Failed to load resource.*favicon/i,
  /Content Security Policy/i,
  /violates the following CSP directive/i,
  /Failed to load resource/i,
];

function isIgnoredError(msg: string): boolean {
  return IGNORED_ERROR_PATTERNS.some((pattern) => pattern.test(msg));
}

for (const [siteName, siteConfig] of Object.entries(sites)) {
  if (!siteConfig) {
    test(`${siteName} — not found in sites.yaml`, async () => {
      test.skip();
    });
    continue;
  }

  for (const pageConfig of siteConfig.pages) {
    const fullUrl = `${siteConfig.url}${pageConfig.path}`;

    test(`${siteName} — ${pageConfig.path} loads correctly`, async ({ page }) => {
      const jsErrors: string[] = [];

      page.on('console', (msg) => {
        if (msg.type() === 'error' && !isIgnoredError(msg.text())) {
          jsErrors.push(msg.text());
        }
      });

      // Navigate and check HTTP status
      const waitUntil = siteConfig.spa ? 'networkidle' as const : 'domcontentloaded' as const;
      const response = await page.goto(fullUrl, { waitUntil });
      expect(response, `No response from ${fullUrl}`).not.toBeNull();
      expect(response!.status(), `HTTP ${response!.status()} at ${fullUrl}`).toBeLessThan(400);

      // Check page has meaningful content
      const bodyText = await page.locator('body').innerText();
      expect(bodyText.trim().length, 'Page body is empty or too short').toBeGreaterThan(10);

      // Optional: check for specific text
      if (pageConfig.expect_text) {
        await expect(page.locator('body')).toContainText(pageConfig.expect_text);
      }

      // Optional: check for specific CSS selector
      if (pageConfig.expect_selector) {
        await expect(page.locator(pageConfig.expect_selector)).toBeVisible();
      }

      // Check for JS errors (soft — log but fail)
      expect(jsErrors, `JS console errors on ${fullUrl}:\n${jsErrors.join('\n')}`).toHaveLength(0);
    });
  }
}
