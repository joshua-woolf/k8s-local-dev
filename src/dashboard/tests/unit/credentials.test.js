import assert from 'node:assert/strict'
import test from 'node:test'
import { CredentialsService } from '../../server/services/credentials.js'

test('reads only the allowlisted Secret for a credential profile', async () => {
  const calls = []
  const coreApi = {
    readNamespacedSecret: async (request) => {
      calls.push(request)
      return {
        data: {
          password: Buffer.from('local-password').toString('base64'),
          username: Buffer.from('app').toString('base64'),
        },
      }
    },
  }
  const service = new CredentialsService(coreApi)

  const credentials = await service.getCredentials('postgres')

  assert.deepEqual(calls, [{ name: 'postgres-app', namespace: 'data' }])
  assert.deepEqual(credentials.fields, [
    { label: 'Username', sensitive: false, value: 'app' },
    { label: 'Password', sensitive: true, value: 'local-password' },
    { label: 'Database', sensitive: false, value: 'app' },
  ])
})

test('returns static access details without reading a Secret', async () => {
  const coreApi = {
    readNamespacedSecret: async () => assert.fail('Secret should not be read'),
  }
  const service = new CredentialsService(coreApi)

  const credentials = await service.getCredentials('grafana')

  assert.deepEqual(credentials.fields, [
    { label: 'Authentication', sensitive: false, value: 'Anonymous Admin' },
  ])
})

test('rejects unknown profiles before accessing Kubernetes', async () => {
  const service = new CredentialsService({
    readNamespacedSecret: async () => assert.fail('Secret should not be read'),
  })

  await assert.rejects(
    service.getCredentials('arbitrary-secret'),
    error => error.statusCode === 404 && error.message === 'Unknown credential profile',
  )
})
