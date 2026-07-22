import { CoreV1Api, DiscoveryV1Api, KubeConfig, NetworkingV1Api } from '@kubernetes/client-node'
import { trace } from '@opentelemetry/api'

const annotationPrefix = 'localdev.dashboard/'

function responseItems(response) {
  return response?.items || response?.body?.items || []
}

function annotationsFor(resource) {
  return resource?.metadata?.annotations || {}
}

function isEnabled(resource) {
  return annotationsFor(resource)[`${annotationPrefix}enabled`] === 'true'
}

function displayMetadata(resource) {
  const annotations = annotationsFor(resource)
  return {
    name: annotations[`${annotationPrefix}name`] || resource.metadata.name,
    category: annotations[`${annotationPrefix}category`] || 'Applications',
    description: annotations[`${annotationPrefix}description`] || '',
    namespace: resource.metadata.namespace,
    resourceName: resource.metadata.name,
  }
}

class KubernetesService {
  constructor(clients = {}) {
    if (clients.networkingApi && clients.coreApi && clients.discoveryApi) {
      this.networkingApi = clients.networkingApi
      this.coreApi = clients.coreApi
      this.discoveryApi = clients.discoveryApi
      return
    }

    const kubeConfig = new KubeConfig()
    kubeConfig.loadFromCluster()
    this.networkingApi = kubeConfig.makeApiClient(NetworkingV1Api)
    this.coreApi = kubeConfig.makeApiClient(CoreV1Api)
    this.discoveryApi = kubeConfig.makeApiClient(DiscoveryV1Api)
  }

  async getDashboardItems() {
    const [ingressResponse, serviceResponse, endpointSliceResponse] = await Promise.all([
      this.networkingApi.listIngressForAllNamespaces(),
      this.coreApi.listServiceForAllNamespaces(),
      this.discoveryApi.listEndpointSliceForAllNamespaces(),
    ])

    const endpointIndex = this.buildEndpointIndex(responseItems(endpointSliceResponse))
    const ingresses = responseItems(ingressResponse)
      .filter(isEnabled)
      .map(ingress => this.ingressItem(ingress, endpointIndex))
    const services = this.deduplicateServices(
      responseItems(serviceResponse)
        .filter(isEnabled)
        .map(service => this.serviceItem(service, endpointIndex)),
    )

    const items = [...ingresses, ...services]
      .sort((left, right) => left.category.localeCompare(right.category) || left.name.localeCompare(right.name))

    const span = trace.getActiveSpan()
    span?.setAttribute('dashboard.items.count', items.length)
    span?.setAttribute('dashboard.ingresses.count', ingresses.length)
    span?.setAttribute('dashboard.services.count', services.length)
    return items
  }

  buildEndpointIndex(endpointSlices) {
    const index = new Map()
    for (const endpointSlice of endpointSlices) {
      const namespace = endpointSlice.metadata?.namespace
      const serviceName = endpointSlice.metadata?.labels?.['kubernetes.io/service-name']
      if (!namespace || !serviceName) continue

      const key = `${namespace}/${serviceName}`
      const current = index.get(key) || { ready: 0, total: 0 }
      for (const endpoint of endpointSlice.endpoints || []) {
        current.total += 1
        if (endpoint.conditions?.ready !== false) current.ready += 1
      }
      index.set(key, current)
    }
    return index
  }

  ingressItem(ingress, endpointIndex) {
    const metadata = displayMetadata(ingress)
    const tlsHosts = new Set((ingress.spec?.tls || []).flatMap(tls => tls.hosts || []))
    const rules = ingress.spec?.rules || []
    const urls = rules
      .filter(rule => rule.host)
      .map(rule => `${tlsHosts.has(rule.host) ? 'https' : 'http'}://${rule.host}`)
    const backendServices = rules.flatMap(rule => rule.http?.paths || [])
      .map(path => path.backend?.service?.name)
      .filter(Boolean)

    return {
      ...metadata,
      id: `ingress:${metadata.namespace}/${metadata.resourceName}`,
      type: 'http',
      status: this.statusForServices(metadata.namespace, backendServices, endpointIndex),
      urls: [...new Set(urls)],
      connections: [],
    }
  }

  serviceItem(service, endpointIndex) {
    const metadata = displayMetadata(service)
    const annotations = annotationsFor(service)
    const host = annotations[`${annotationPrefix}host`]
    const hostPort = Number.parseInt(annotations[`${annotationPrefix}port`], 10)
    const protocol = annotations[`${annotationPrefix}protocol`] || 'tcp'
    let connections

    if (host && Number.isInteger(hostPort)) {
      connections = [{
        label: protocol.toUpperCase(),
        endpoint: `${host}:${hostPort}`,
      }]
    }
    else {
      connections = (service.spec?.ports || []).map((port) => {
        const servicePort = Number(port.port)
        return {
          label: port.name || `${port.protocol || 'TCP'} ${servicePort}`,
          endpoint: `${metadata.resourceName}.${metadata.namespace}.svc.cluster.local:${servicePort}`,
          command: `kubectl --context kind-local-dev --namespace ${metadata.namespace} port-forward service/${metadata.resourceName} ${servicePort}:${servicePort}`,
        }
      })
    }

    return {
      ...metadata,
      id: `service:${metadata.namespace}/${metadata.resourceName}`,
      type: 'service',
      status: this.statusForServices(metadata.namespace, [metadata.resourceName], endpointIndex),
      urls: [],
      connections,
    }
  }

  statusForServices(namespace, serviceNames, endpointIndex) {
    if (serviceNames.length === 0) return 'unknown'
    return serviceNames.every((serviceName) => {
      return (endpointIndex.get(`${namespace}/${serviceName}`)?.ready || 0) > 0
    }) ? 'ready' : 'unavailable'
  }

  deduplicateServices(services) {
    const deduplicated = new Map()
    const preferred = [...services].sort((left, right) => {
      const leftRank = left.resourceName.endsWith('-rw') ? 0 : 1
      const rightRank = right.resourceName.endsWith('-rw') ? 0 : 1
      return leftRank - rightRank
    })

    for (const service of preferred) {
      const key = `${service.namespace}/${service.name}`
      if (!deduplicated.has(key)) {
        deduplicated.set(key, service)
      }
    }
    return [...deduplicated.values()]
  }
}

export { KubernetesService, annotationPrefix, responseItems }
