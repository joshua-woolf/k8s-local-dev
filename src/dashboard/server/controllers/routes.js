import { trace, SpanStatusCode, context } from '@opentelemetry/api'
import { KubernetesService } from '../services/kubernetes.js'

class RoutesController {
  constructor() {
    this.kubernetesService = new KubernetesService()
  }

  async getRoutes(req, res, next) {
    const activeContext = context.active()
    const tracer = trace.getTracer('dashboard')
    const span = tracer.startSpan('get_routes', { parent: activeContext })

    return context.with(trace.setSpan(activeContext, span), async () => {
      try {
        const [ingresses, ingressRoutes] = await Promise.all([
          this.kubernetesService.getIngresses(),
          this.kubernetesService.getIngressRoutes(),
        ])

        span.setAttribute('ingress_count', ingresses.length)
        span.setAttribute('ingressroute_count', ingressRoutes.length)
        span.setStatus({ code: SpanStatusCode.OK })

        res.json([...ingresses, ...ingressRoutes])
      }
      catch (error) {
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: error.message,
        })
        next(error)
      }
      finally {
        span.end()
      }
    })
  }
}

const routesController = new RoutesController().getRoutes.bind(new RoutesController())

export { routesController, RoutesController }
