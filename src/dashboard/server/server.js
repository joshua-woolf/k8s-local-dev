import express from 'express'
import path, { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { credentialsController } from './controllers/credentials.js'
import { servicesController } from './controllers/services.js'
import { errorHandler } from './middleware/errorHandler.js'
import { requestLogger } from './middleware/requestLogger.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

class DashboardServer {
  constructor({ controller = servicesController, credentials = credentialsController } = {}) {
    this.app = express()
    this.port = Number.parseInt(process.env.PORT || '3000', 10)
    this.controller = controller
    this.credentials = credentials
    this.setupMiddleware()
    this.setupRoutes()
    this.setupErrorHandling()
  }

  setupMiddleware() {
    this.app.use(requestLogger)
    this.app.use((_req, res, next) => {
      res.setHeader('X-Content-Type-Options', 'nosniff')
      res.setHeader('X-Frame-Options', 'DENY')
      res.setHeader('Referrer-Policy', 'no-referrer')
      res.setHeader('Content-Security-Policy', "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; connect-src 'self'")
      next()
    })
    this.app.use(express.static(path.join(__dirname, 'public')))
  }

  setupRoutes() {
    this.app.get('/healthz', (_req, res) => res.json({ status: 'ok' }))
    this.app.get('/readyz', (_req, res) => res.json({ status: 'ready' }))
    this.app.get('/api/services', this.controller)
    this.app.get('/api/credentials/:profile', this.credentials)
    this.app.use((_req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'index.html'))
    })
  }

  setupErrorHandling() {
    this.app.use(errorHandler)
  }

  start() {
    return new Promise((resolve) => {
      const httpServer = this.app.listen(this.port, () => {
        console.log(JSON.stringify({ event: 'server_started', port: this.port }))
        resolve(httpServer)
      })
    })
  }

  async shutdown(httpServer) {
    await new Promise((resolve, reject) => {
      httpServer.close(error => error ? reject(error) : resolve())
    })
  }
}

async function main() {
  const dashboardServer = new DashboardServer()
  const httpServer = await dashboardServer.start()
  let stopping = false

  const stop = async (signal) => {
    if (stopping) return
    stopping = true
    console.log(JSON.stringify({ event: 'server_stopping', signal }))
    await dashboardServer.shutdown(httpServer)
    const { shutdownTelemetry } = await import('./tracing.js')
    await shutdownTelemetry()
  }

  process.once('SIGTERM', () => stop('SIGTERM').catch(error => console.error(error)))
  process.once('SIGINT', () => stop('SIGINT').catch(error => console.error(error)))
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  main().catch((error) => {
    console.error(error)
    process.exitCode = 1
  })
}

export { DashboardServer, main }
