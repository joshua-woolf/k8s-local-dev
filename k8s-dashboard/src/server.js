const express = require('express');
const cors = require('cors');
const k8s = require('@kubernetes/client-node');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// Initialize Kubernetes client
const kc = new k8s.KubeConfig();
kc.loadFromCluster(); // This will load the service account credentials when running in cluster

const k8sApi = kc.makeApiClient(k8s.NetworkingV1Api);
const customObjectsApi = kc.makeApiClient(k8s.CustomObjectsApi);
const coreV1Api = kc.makeApiClient(k8s.CoreV1Api);

app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

// Helper function to get credentials from secret
async function getCredentialsFromSecret(namespace, secretName, usernameAnnotation, passwordAnnotation, passwordJsonPath) {
  try {
    if (!secretName) return null;

    const secret = await coreV1Api.readNamespacedSecret(secretName, namespace);
    const username = usernameAnnotation;
    let password;

    if (passwordJsonPath) {
      // Evaluate the JSONPath expression
      const jsonPath = passwordJsonPath.replace(/[{}]/g, '');
      const data = secret.body.data;
      password = Buffer.from(data[jsonPath.split('.')[2]], 'base64').toString();
    }

    return username && password ? { username, password } : null;
  } catch (error) {
    console.error(`Error fetching credentials from secret: ${error.message}`);
    return null;
  }
}

// API endpoint to get all ingresses and ingressroutes
app.get('/api/routes', async (req, res) => {
  try {
    // Get standard ingresses
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

    // Get Traefik IngressRoutes
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

    res.json([...ingresses, ...ingressRoutes]);
  } catch (error) {
    console.error('Error fetching routes:', error);
    res.status(500).json({ error: 'Failed to fetch routes' });
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
