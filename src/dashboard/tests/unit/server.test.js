import assert from 'node:assert/strict'
import test from 'node:test'
import { DashboardServer } from '../../server/server.js'

test('serves health, API, and browser security headers', async (context) => {
  const controller = (_req, res) => res.json([{ name: 'Dashboard' }])
  const credentials = (req, res) => {
    res.setHeader('Cache-Control', 'no-store')
    res.json({ profile: req.params.profile })
  }
  const dashboard = new DashboardServer({ controller, credentials })
  dashboard.port = 0
  const httpServer = await dashboard.start()
  context.after(() => dashboard.shutdown(httpServer))
  const { port } = httpServer.address()

  const healthResponse = await fetch(`http://127.0.0.1:${port}/healthz`)
  const apiResponse = await fetch(`http://127.0.0.1:${port}/api/services`)
  const credentialsResponse = await fetch(`http://127.0.0.1:${port}/api/credentials/postgres`)

  assert.equal(healthResponse.status, 200)
  assert.equal(healthResponse.headers.get('x-frame-options'), 'DENY')
  assert.deepEqual(await apiResponse.json(), [{ name: 'Dashboard' }])
  assert.equal(credentialsResponse.headers.get('cache-control'), 'no-store')
  assert.deepEqual(await credentialsResponse.json(), { profile: 'postgres' })
})
