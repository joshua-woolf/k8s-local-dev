const k8s = require('@kubernetes/client-node');
const { trace, SpanStatusCode } = require('@opentelemetry/api');
const { KubernetesService } = require('../services/kubernetes');

class RoutesController {
  constructor() {
    this.kubernetesService = new KubernetesService();
  }

  async getRoutes(req, res, next) {
    const tracer = trace.getTracer('dashboard');
    const span = tracer.startSpan('get_routes');

    try {
      const [ingresses, ingressRoutes] = await Promise.all([
        this.kubernetesService.getIngresses(span),
        this.kubernetesService.getIngressRoutes(span)
      ]);

      span.setAttribute('ingress_count', ingresses.length);
      span.setAttribute('ingressroute_count', ingressRoutes.length);
      span.setStatus({ code: SpanStatusCode.OK });

      res.json([...ingresses, ...ingressRoutes]);
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message
      });
      next(error);
    } finally {
      span.end();
    }
  }
}

const routesController = new RoutesController().getRoutes.bind(new RoutesController());

module.exports = { routesController, RoutesController };
