import { trace } from '@opentelemetry/api'
import { KubernetesService } from '../services/kubernetes.js'

class ServicesController {
  constructor(kubernetesService = new KubernetesService()) {
    this.kubernetesService = kubernetesService
  }

  async getServices(_req, res, next) {
    try {
      const items = await this.kubernetesService.getDashboardItems()
      trace.getActiveSpan()?.setAttribute('http.response.body.items', items.length)
      res.json(items)
    }
    catch (error) {
      next(error)
    }
  }
}

let controller
const servicesController = (req, res, next) => {
  controller ||= new ServicesController()
  return controller.getServices(req, res, next)
}

export { servicesController, ServicesController }
