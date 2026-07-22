import { test, expect } from '@playwright/test'

test('dashboard shows its own ready service card', async ({ page }) => {
  await page.goto('/')

  const serviceCard = page.locator('.service-card').filter({ hasText: 'Dashboard' })

  await expect(serviceCard).toBeVisible()
  await expect(serviceCard.locator('.service-name')).toHaveText('Dashboard')
  await expect(serviceCard.locator('.status-ready')).toBeVisible()
  await expect(serviceCard.getByRole('link', { name: 'https://dashboard.k8s.localhost' })).toBeVisible()
})
