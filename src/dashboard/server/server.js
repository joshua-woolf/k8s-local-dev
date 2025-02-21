import { setupTelemetry } from './tracing.js'
import express from 'express'
import cors from 'cors'
import path, { dirname } from 'path'
import { fileURLToPath } from 'url'
import { routesController } from './controllers/routes.js'
import { errorHandler } from './middleware/errorHandler.js'
import { requestLogger } from './middleware/requestLogger.js'
import { trace, SpanStatusCode } from '@opentelemetry/api'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

setupTelemetry()

class DashboardServer {
  constructor() {
    this.app = express()
    this.port = process.env.PORT || 3000
    this.setupMiddleware()
    this.setupRoutes()
    this.setupErrorHandling()
  }

  setupMiddleware() {
    this.app.use(cors({
      origin: process.env.CORS_ORIGIN || '*',
      methods: ['GET', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }))

    this.app.use(express.static(path.join(__dirname, 'public')))

    this.app.use(requestLogger)
  }

  setupRoutes() {
    this.app.get('/api/routes', routesController)

    this.app.get('*', (_req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'index.html'))
    })
  }

  setupErrorHandling() {
    this.app.use(errorHandler)
  }

  start() {
    return new Promise((resolve, reject) => {
      try {
        const tracer = trace.getTracer('dashboard')
        const span = tracer.startSpan('server_start')

        const server = this.app.listen(this.port, () => {
          span.setAttribute('port', this.port)
          span.addEvent('server_started', {
            attributes: {
              port: this.port,
            },
          })
          span.setStatus({ code: SpanStatusCode.OK })
          span.end()
          resolve(server)
        })

        process.on('SIGTERM', () => this.shutdown(server))
        process.on('SIGINT', () => this.shutdown(server))
      }
      catch (error) {
        reject(error)
      }
    })
  }

  async shutdown(server) {
    const tracer = trace.getTracer('dashboard')
    const span = tracer.startSpan('server_shutdown')

    try {
      span.addEvent('shutting_down_server')
      await new Promise(resolve => server.close(resolve))
      span.addEvent('server_shutdown_complete')
      span.setStatus({ code: SpanStatusCode.OK })
      span.end()
      process.exit(0)
    }
    catch (error) {
      span.addEvent('server_shutdown_error', {
        attributes: {
          error: error.message,
          stack: error.stack,
        },
      })
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      })
      span.end()
      process.exit(1)
    }
  }
}

const server = new DashboardServer()

server.start().catch((error) => {
  const tracer = trace.getTracer('dashboard')
  const span = tracer.startSpan('server_start_error')
  span.addEvent('failed_to_start_server', {
    attributes: {
      error: error.message,
      stack: error.stack,
    },
  })
  span.setStatus({
    code: SpanStatusCode.ERROR,
    message: error.message,
  })
  span.end()
  process.exit(1)
})

export { DashboardServer }
