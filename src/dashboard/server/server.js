const { setupTelemetry } = require('./tracing');

setupTelemetry();

const express = require('express');
const cors = require('cors');
const k8s = require('@kubernetes/client-node');
const path = require('path');
const { trace, context, SpanStatusCode } = require('@opentelemetry/api');

const app = express();
const port = process.env.PORT || 3000;

const kc = new k8s.KubeConfig();
kc.loadFromCluster();

const k8sApi = kc.makeApiClient(k8s.NetworkingV1Api);
const customObjectsApi = kc.makeApiClient(k8s.CustomObjectsApi);
const coreV1Api = kc.makeApiClient(k8s.CoreV1Api);

app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

async function getCredentialsFromSecret(namespace, secretName, usernameAnnotation, passwordAnnotation, passwordJsonPath) {
  const tracer = trace.getTracer('k8s-dashboard');
  const span = tracer.startSpan('getCredentialsFromSecret');

  try {
    if (!secretName) return null;

    span.setAttribute('namespace', namespace);
    span.setAttribute('secretName', secretName);

    const secret = await coreV1Api.readNamespacedSecret(secretName, namespace);
    const username = usernameAnnotation;
    let password;

    if (passwordJsonPath) {
      const jsonPath = passwordJsonPath.replace(/[{}]/g, '');
      const data = secret.body.data;
      password = Buffer.from(data[jsonPath.split('.')[2]], 'base64').toString();
    }

    span.setStatus({ code: SpanStatusCode.OK });
    return username && password ? { username, password } : null;
  } catch (error) {
    console.error(`Error fetching credentials from secret: ${error.message}`);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message
    });
    return null;
  } finally {
    span.end();
  }
}

app.get('/api/routes', async (req, res) => {
  const tracer = trace.getTracer('k8s-dashboard');
  const span = tracer.startSpan('get_routes');

  try {
    const ingressSpan = tracer.startSpan('get_ingresses');
    const ingressResponse = await k8sApi.listIngressForAllNamespaces();
    const ingresses = await Promise.all(ingressResponse.body.items.map(async ingress => {
      const credentials = await getCredentialsFromSecret(
        ingress.metadata.namespace,
        ingress.metadata.annotations?.['credentials-password-secret'],
        ingress.metadata.annotations?.['credentials-username'],
        ingress.metadata.annotations?.['credentials-password'],
        ingress.metadata.annotations?.['credentials-password-jsonpath']
      );

      return {
        name: ingress.metadata.annotations?.['friendly-name'] || ingress.metadata.name,
        urls: ingress.spec.rules.map(rule => `https://${rule.host}`),
        credentials
      };
    }));
    ingressSpan.setStatus({ code: SpanStatusCode.OK });
    ingressSpan.end();

    const ingressRouteSpan = tracer.startSpan('get_ingressroutes');
    const ingressRouteResponse = await customObjectsApi.listClusterCustomObject(
      'traefik.io',
      'v1alpha1',
      'ingressroutes'
    );
    const ingressRoutes = ingressRouteResponse.body.items.map(route => ({
      name: route.metadata.annotations?.['friendly-name'] || route.metadata.name,
      urls: route.spec.routes.map(r => {
        const host = route.spec.routes[0].match.split('Host(`')[1]?.split('`)')[0];
        return host ? `https://${host}` : 'No host specified';
      })
    }));
    ingressRouteSpan.setStatus({ code: SpanStatusCode.OK });
    ingressRouteSpan.end();

    span.setAttribute('ingress_count', ingresses.length);
    span.setAttribute('ingressroute_count', ingressRoutes.length);
    span.setStatus({ code: SpanStatusCode.OK });

    res.json([...ingresses, ...ingressRoutes]);
  } catch (error) {
    console.error('Error fetching routes:', error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message
    });
    res.status(500).json({ error: 'Failed to fetch routes' });
  } finally {
    span.end();
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
