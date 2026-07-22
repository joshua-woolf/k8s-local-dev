import { trace } from '@opentelemetry/api'

const requestLogger = (req, res, next) => {
  const startTime = Date.now()
  const span = trace.getActiveSpan()

  res.on('finish', () => {
    const duration = Date.now() - startTime
    span?.setAttribute('dashboard.http.duration_ms', duration)
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: duration,
    }))
  })

  next()
}

export { requestLogger }
