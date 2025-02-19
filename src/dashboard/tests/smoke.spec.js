const { test, expect } = require('@playwright/test');

test('given dashboard is deployed when accessing homepage then dashboard route card exists', async ({ page }) => {
  // Arrange
  await page.goto('https://dashboard.local.dev');

  // Act
  const routeCard = page.locator('.route-card').filter({ hasText: 'Dashboard' });

  // Assert
  await expect(routeCard).toBeVisible();
  await expect(routeCard.locator('.route-name')).toHaveText('Dashboard');
  await expect(routeCard.locator('.route-url')).toHaveText('https://dashboard.local.dev');
});
