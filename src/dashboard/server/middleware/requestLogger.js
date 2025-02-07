const { trace, SpanStatusCode } = require('@opentelemetry/api');

const requestLogger = (req, res, next) => {
  const tracer = trace.getTracer('dashboard');
  const span = tracer.startSpan('request_logger');

  try {
    const startTime = Date.now();

    span.setAttribute('http.method', req.method);
    span.setAttribute('http.url', req.url);
    span.setAttribute('http.user_agent', req.get('user-agent'));

    res.on('finish', () => {
      const duration = Date.now() - startTime;
      span.setAttribute('http.status_code', res.statusCode);
      span.setAttribute('http.duration_ms', duration);

      console.log({
        timestamp: new Date().toISOString(),
        method: req.method,
        url: req.url,
        status: res.statusCode,
        duration: `${duration}ms`,
        userAgent: req.get('user-agent')
      });

      span.setStatus({ code: SpanStatusCode.OK });
      span.end();
    });

    next();
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message
    });
    span.end();
    next(error);
  }
};

module.exports = { requestLogger };
