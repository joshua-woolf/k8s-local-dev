import { CoreV1Api, KubeConfig } from '@kubernetes/client-node'
import { ErrorResponse } from '../middleware/errorHandler.js'

const secretNamespace = 'data'

const credentialProfiles = Object.freeze({
  clickhouse: {
    secretName: 'clickhouse-credentials',
    fields: [
      { label: 'Username', key: 'username' },
      { label: 'Password', key: 'password', sensitive: true },
      { label: 'Database', value: 'app' },
    ],
  },
  grafana: {
    fields: [
      { label: 'Authentication', value: 'Anonymous Admin' },
    ],
  },
  none: {
    fields: [
      { label: 'Authentication', value: 'None' },
    ],
  },
  pgadmin: {
    secretName: 'pgadmin-credentials',
    fields: [
      { label: 'Email', value: 'admin@local.dev' },
      { label: 'Password', key: 'password', sensitive: true },
    ],
  },
  postgres: {
    secretName: 'postgres-app',
    fields: [
      { label: 'Username', key: 'username' },
      { label: 'Password', key: 'password', sensitive: true },
      { label: 'Database', value: 'app' },
    ],
  },
  valkey: {
    secretName: 'valkey-credentials',
    fields: [
      { label: 'Username', key: 'username' },
      { label: 'Password', key: 'password', sensitive: true },
    ],
  },
})

function secretData(response) {
  return response?.data || response?.body?.data || {}
}

function decodeSecretValue(data, key) {
  const encoded = data[key]
  if (!encoded) throw new Error(`Credential Secret is missing the ${key} field`)
  return Buffer.from(encoded, 'base64').toString('utf8')
}

class CredentialsService {
  constructor(coreApi) {
    if (coreApi) {
      this.coreApi = coreApi
      return
    }

    const kubeConfig = new KubeConfig()
    kubeConfig.loadFromCluster()
    this.coreApi = kubeConfig.makeApiClient(CoreV1Api)
  }

  async getCredentials(profileName) {
    const profile = credentialProfiles[profileName]
    if (!profile) throw new ErrorResponse('Unknown credential profile', 404)

    let data = {}
    if (profile.secretName) {
      const secret = await this.coreApi.readNamespacedSecret({
        name: profile.secretName,
        namespace: secretNamespace,
      })
      data = secretData(secret)
    }

    return {
      profile: profileName,
      fields: profile.fields.map(field => ({
        label: field.label,
        sensitive: field.sensitive || false,
        value: field.value ?? decodeSecretValue(data, field.key),
      })),
    }
  }
}

export { credentialProfiles, CredentialsService, decodeSecretValue, secretNamespace }
