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
  const statusCode = err.statusCode || 500
  const span = trace.getActiveSpan()
  span?.recordException(err)
  span?.setStatus({
    code: SpanStatusCode.ERROR,
    message: err.message,
  })

  const error = {
    status: err.status || 'error',
    message: statusCode >= 500 && process.env.NODE_ENV !== 'development'
      ? 'Internal Server Error'
      : err.message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  }
  res.status(statusCode).json(error)
}

export { errorHandler, ErrorResponse }
