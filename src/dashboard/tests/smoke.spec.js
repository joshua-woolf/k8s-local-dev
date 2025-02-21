import { test, expect } from '@playwright/test'

test('given dashboard is deployed when accessing homepage then dashboard route card exists', async ({ page }) => {
  await page.goto('/')

  const routeCard = page.locator('.route-card').filter({ hasText: 'Dashboard' })

  await expect(routeCard).toBeVisible()
  await expect(routeCard.locator('.route-name')).toHaveText('Dashboard')
  await expect(routeCard.locator('.route-url')).toHaveText('https://dashboard.local.dev')
})
