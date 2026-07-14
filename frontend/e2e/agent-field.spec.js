import { test, expect } from '@playwright/test';

/**
 * Parcours carte / filtres validation — API mockée.
 * Live API : E2E_LIVE=1 npm run test:e2e:live
 */

test.describe('Carte — filtre validation', () => {
  test.beforeEach(async ({ page }) => {
    await page.route('**/api/v1/**', async (route) => {
      const url = route.request().url();
      if (url.includes('/points/') && route.request().method() === 'GET') {
        const validatedOnly = url.includes('is_validated=true');
        const pendingOnly = url.includes('validation_status=pending');
        const points = [
          {
            id: 1,
            ph: 6.2,
            humidity_pct: 35,
            soil_type: 'limoneux',
            ph_color: 'yellow',
            fertility_class: 'moyenne',
            lat: 6.35,
            lon: 1.25,
            is_validated: true,
            validation_status: 'validated',
          },
          {
            id: 2,
            ph: 5.1,
            humidity_pct: 28,
            soil_type: 'argileux',
            ph_color: 'red',
            fertility_class: 'faible',
            lat: 6.36,
            lon: 1.26,
            is_validated: false,
            validation_status: 'pending',
          },
        ];
        let results = points;
        if (validatedOnly) results = points.filter((p) => p.is_validated);
        if (pendingOnly) results = points.filter((p) => p.validation_status === 'pending');
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ count: results.length, results }),
        });
      }
      if (url.includes('/auth/') || url.includes('/platform/') || url.includes('/weather/')
          || url.includes('/sentinel/') || url.includes('/nasa/') || url.includes('/dashboard/')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({}),
        });
      }
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({}),
      });
    });

    await page.goto('/index.html');
  });

  test('filtre validation présent avec modes Validés / En attente / Tous', async ({ page }) => {
    const select = page.locator('#filter-validation');
    await expect(select).toBeVisible();
    await expect(select).toHaveValue('validated');
    await select.selectOption('pending');
    await expect(select).toHaveValue('pending');
    await select.selectOption('all');
    await expect(select).toHaveValue('all');
  });

  test('appliquer filtres envoie le mode validation', async ({ page }) => {
    const requests = [];
    page.on('request', (req) => {
      if (req.url().includes('/points/')) requests.push(req.url());
    });
    await page.locator('#filter-validation').selectOption('pending');
    await page.locator('#btn-apply-filters').click();
    await page.waitForTimeout(500);
    const hit = requests.find((u) => u.includes('validation_status=pending'));
    expect(hit).toBeTruthy();
  });
});
