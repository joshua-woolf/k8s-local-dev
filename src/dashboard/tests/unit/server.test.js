import assert from 'node:assert/strict'
import test from 'node:test'
import { DashboardServer } from '../../server/server.js'

test('serves health, API, and browser security headers', async (context) => {
  const controller = (_req, res) => res.json([{ name: 'Dashboard' }])
  const dashboard = new DashboardServer({ controller })
  dashboard.port = 0
  const httpServer = await dashboard.start()
  context.after(() => dashboard.shutdown(httpServer))
  const { port } = httpServer.address()

  const healthResponse = await fetch(`http://127.0.0.1:${port}/healthz`)
  const apiResponse = await fetch(`http://127.0.0.1:${port}/api/services`)

  assert.equal(healthResponse.status, 200)
  assert.equal(healthResponse.headers.get('x-frame-options'), 'DENY')
  assert.deepEqual(await apiResponse.json(), [{ name: 'Dashboard' }])
})
