const k8s = require('@kubernetes/client-node');
const { trace, SpanStatusCode, context } = require('@opentelemetry/api');

class KubernetesService {
  constructor() {
    this.kc = new k8s.KubeConfig();
    this.kc.loadFromCluster();
    this.k8sApi = this.kc.makeApiClient(k8s.NetworkingV1Api);
    this.customObjectsApi = this.kc.makeApiClient(k8s.CustomObjectsApi);
    this.coreV1Api = this.kc.makeApiClient(k8s.CoreV1Api);
  }

  async getIngresses() {
    const activeContext = context.active();
    const tracer = trace.getTracer('dashboard');
    const span = tracer.startSpan('get_ingresses', { parent: activeContext });

    return context.with(trace.setSpan(activeContext, span), async () => {
      try {
        const ingressResponse = await this.k8sApi.listIngressForAllNamespaces();
        const ingresses = await Promise.all(
          (ingressResponse?.items || []).map(async (ingress) => {
            const credentials = await this.getCredentialsFromSecret(
              ingress.metadata.namespace,
              ingress.metadata.annotations?.['credentials-password-secret'],
              ingress.metadata.annotations?.['credentials-username'],
              ingress.metadata.annotations?.['credentials-password-jsonpath']
            );

            return {
              name: ingress.metadata.annotations?.['friendly-name'] || ingress.metadata.name,
              urls: ingress.spec.rules.map((rule) => `https://${rule.host}`),
              credentials,
            };
          })
        );

        span.setStatus({ code: SpanStatusCode.OK });
        return ingresses;
      } catch (error) {
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: error.message,
        });
        throw error;
      } finally {
        span.end();
      }
    });
  }

  async getIngressRoutes() {
    const activeContext = context.active();
    const tracer = trace.getTracer('dashboard');
    const span = tracer.startSpan('get_ingressroutes', { parent: activeContext });

    return context.with(trace.setSpan(activeContext, span), async () => {
      try {
        const ingressRouteResponse = await this.customObjectsApi.listClusterCustomObject({
          group: 'traefik.containo.us',
          version: 'v1alpha1',
          plural: 'ingressroutes',
        });

        const ingresses = await Promise.all(
          (ingressRouteResponse?.items || []).map(async (ingress) => {
            const credentials = await this.getCredentialsFromSecret(
              ingress.metadata.namespace,
              ingress.metadata.annotations?.['credentials-password-secret'],
              ingress.metadata.annotations?.['credentials-username'],
              ingress.metadata.annotations?.['credentials-password-jsonpath']
            );

            return {
              name: ingress.metadata.annotations?.['friendly-name'] || ingress.metadata.name,
              urls: ingress.spec.routes.map((route) => route.match.split('Host(`')[1]?.split('`)')[0]),
              credentials,
            };
          })
        );

        span.setStatus({ code: SpanStatusCode.OK });
        return ingresses;
      } catch (error) {
        if (error.statusCode === 404) {
          console.log('Traefik CRDs not found - skipping IngressRoute processing');
          span.setStatus({
            code: SpanStatusCode.OK,
            message: 'Traefik CRDs not installed',
          });
          return [];
        }
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: error.message,
        });
        throw error;
      } finally {
        span.end();
      }
    });
  }

  async getCredentialsFromSecret(
    namespace,
    secretName,
    usernameAnnotation,
    passwordJsonPath
  ) {
    const activeContext = context.active();
    const tracer = trace.getTracer('dashboard');
    const span = tracer.startSpan('get_credentials_from_secret', { parent: activeContext });

    return context.with(trace.setSpan(activeContext, span), async () => {
      try {
        if (!secretName) return null;

        span.setAttribute('namespace', namespace);
        span.setAttribute('secretName', secretName);

        const secret = await this.coreV1Api.readNamespacedSecret({
          name: secretName,
          namespace: namespace
        });

        const username = usernameAnnotation;
        let password;

        if (passwordJsonPath) {
          const jsonPath = passwordJsonPath.replace(/[{}]/g, '');
          const data = secret.data;
          password = Buffer.from(data[jsonPath.split('.')[2]], 'base64').toString();
        }

        span.setStatus({ code: SpanStatusCode.OK });
        return username && password ? { username, password } : null;
      } catch (error) {
        console.error(`Error fetching credentials from secret: ${error.message}`);
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: error.message,
        });
        return null;
      } finally {
        span.end();
      }
    });
  }
}

module.exports = { KubernetesService };
