import { test, expect } from '@playwright/test'

test('dashboard shows its own ready service card', async ({ page }) => {
  await page.goto('/')

  const serviceCard = page.locator('.service-card').filter({ hasText: 'Dashboard' })

  await expect(serviceCard).toBeVisible()
  await expect(serviceCard.locator('.service-name')).toHaveText('Dashboard')
  await expect(serviceCard.locator('.status-ready')).toBeVisible()
  await expect(serviceCard.getByRole('link', { name: 'https://dashboard.k8s.localhost' })).toBeVisible()
})

test('dashboard shows data tools and host database endpoints', async ({ page }) => {
  await page.goto('/')

  for (const url of [
    'https://pgadmin.k8s.localhost',
    'https://kafbat.k8s.localhost',
    'https://clickhouse.k8s.localhost',
    'https://valkey-ui.k8s.localhost',
  ]) {
    await expect(page.getByRole('link', { name: url })).toBeVisible()
  }

  for (const endpoint of [
    'postgres.k8s.localhost:5432',
    'clickhouse.k8s.localhost:9000',
    'kafka.k8s.localhost:9094',
    'valkey.k8s.localhost:6379',
  ]) {
    await expect(page.getByText(endpoint, { exact: true })).toBeVisible()
  }
})

test('Valkey Admin automatically connects to the local instance', async ({ page }) => {
  await page.goto('https://valkey-ui.k8s.localhost')

  await expect(page.getByText('Local Valkey', { exact: true })).toBeVisible({ timeout: 15_000 })
  await expect(page.getByText(/Metrics, CPU and Memory Usage for instance/)).toBeVisible()
  await expect(page.getByText('You Have No Connections!')).toHaveCount(0)
})
