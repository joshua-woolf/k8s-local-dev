import { trace, SpanStatusCode } from '@opentelemetry/api'

class ErrorResponse extends Error {
  constructor(message, statusCode) {
    super(message)
    this.statusCode = statusCode
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error'
    Error.captureStackTrace(this, this.constructor)
  }
}

const errorHandler = (err, _req, res, _next) => {
  const tracer = trace.getTracer('dashboard')
  const span = tracer.startSpan('error_handler')

  try {
    const error = {
      status: err.status || 'error',
      message: err.message || 'Internal Server Error',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    }

    span.setAttribute('error', true)
    span.setAttribute('error.type', err.name)
    span.setAttribute('error.message', err.message)
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: err.message,
    })

    const statusCode = err.statusCode || 500
    res.status(statusCode).json(error)
  }
  finally {
    span.end()
  }
}

export { errorHandler, ErrorResponse }
