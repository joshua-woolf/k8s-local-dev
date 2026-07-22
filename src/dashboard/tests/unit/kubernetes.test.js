import assert from 'node:assert/strict'
import test from 'node:test'
import { KubernetesService } from '../../server/services/kubernetes.js'

function createService({ ingresses = [], services = [], endpointSlices = [] } = {}) {
  return new KubernetesService({
    networkingApi: { listIngressForAllNamespaces: async () => ({ items: ingresses }) },
    coreApi: { listServiceForAllNamespaces: async () => ({ items: services }) },
    discoveryApi: { listEndpointSliceForAllNamespaces: async () => ({ items: endpointSlices }) },
  })
}

test('returns only explicitly enabled ingresses with endpoint readiness', async () => {
  const service = createService({
    ingresses: [
      {
        metadata: {
          name: 'dashboard',
          namespace: 'dashboard',
          annotations: {
            'localdev.dashboard/enabled': 'true',
            'localdev.dashboard/name': 'Dashboard',
            'localdev.dashboard/credentials': 'none',
          },
        },
        spec: {
          rules: [{
            host: 'dashboard.k8s.localhost',
            http: { paths: [{ backend: { service: { name: 'dashboard' } } }] },
          }],
          tls: [{ hosts: ['dashboard.k8s.localhost'] }],
        },
      },
      { metadata: { name: 'private', namespace: 'dashboard' }, spec: { rules: [] } },
    ],
    endpointSlices: [{
      metadata: {
        namespace: 'dashboard',
        labels: { 'kubernetes.io/service-name': 'dashboard' },
      },
      endpoints: [{ conditions: { ready: true } }],
    }],
  })

  const items = await service.getDashboardItems()

  assert.equal(items.length, 1)
  assert.equal(items[0].name, 'Dashboard')
  assert.equal(items[0].status, 'ready')
  assert.equal(items[0].credentialProfile, 'none')
  assert.deepEqual(items[0].urls, ['https://dashboard.k8s.localhost'])
})

test('builds port-forward instructions for annotated cluster services', async () => {
  const service = createService({
    services: [{
      metadata: {
        name: 'postgres-rw',
        namespace: 'data',
        annotations: {
          'localdev.dashboard/enabled': 'true',
          'localdev.dashboard/name': 'PostgreSQL',
          'localdev.dashboard/category': 'Data',
        },
      },
      spec: { ports: [{ name: 'postgresql', port: 5432 }] },
    }],
    endpointSlices: [{
      metadata: {
        namespace: 'data',
        labels: { 'kubernetes.io/service-name': 'postgres-rw' },
      },
      endpoints: [{ conditions: {} }],
    }],
  })

  const [item] = await service.getDashboardItems()

  assert.equal(item.status, 'ready')
  assert.equal(item.connections[0].endpoint, 'postgres-rw.data.svc.cluster.local:5432')
  assert.match(item.connections[0].command, /port-forward service\/postgres-rw 5432:5432$/)
})

test('uses an explicitly advertised host endpoint without constructing commands', async () => {
  const service = createService({
    services: [{
      metadata: {
        name: 'kafka-external-bootstrap',
        namespace: 'data',
        annotations: {
          'localdev.dashboard/enabled': 'true',
          'localdev.dashboard/name': 'Kafka',
          'localdev.dashboard/host': 'kafka.k8s.localhost',
          'localdev.dashboard/port': '9094',
          'localdev.dashboard/protocol': 'kafka',
        },
      },
      spec: { ports: [{ port: 9094 }] },
    }],
  })

  const [item] = await service.getDashboardItems()

  assert.deepEqual(item.connections, [{ label: 'KAFKA', endpoint: 'kafka.k8s.localhost:9094' }])
})
