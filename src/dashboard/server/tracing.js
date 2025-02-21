import opentelemetry from '@opentelemetry/sdk-node'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-proto'
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-proto'
import { Resource } from '@opentelemetry/resources'
import { ExpressInstrumentation } from '@opentelemetry/instrumentation-express'
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http'
import { trace, SpanStatusCode } from '@opentelemetry/api'

function setupTelemetry() {
  const tracer = trace.getTracer('dashboard')
  const span = tracer.startSpan('setup_telemetry')

  try {
    span.addEvent('initializing_opentelemetry')

    const resource = new Resource({
      [ResourceAttributes.SERVICE_NAME]: 'dashboard',
      [ResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [ResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
    })

    const commonExporterConfig = {
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
      timeoutMillis: 30000,
      concurrencyLimit: 10,
    }

    span.setAttribute('otlp_endpoint', commonExporterConfig.url)

    const traceExporter = new OTLPTraceExporter({
      ...commonExporterConfig,
      url: `${commonExporterConfig.url}/v1/traces`,
    })

    const metricExporter = new OTLPMetricExporter({
      ...commonExporterConfig,
      url: `${commonExporterConfig.url}/v1/metrics`,
    })

    const sdk = new opentelemetry.NodeSDK({
      resource: resource,
      traceExporter: traceExporter,
      metricReader: new opentelemetry.metrics.PeriodicExportingMetricReader({
        exporter: metricExporter,
        exportIntervalMillis: 1000,
      }),
      instrumentations: [
        getNodeAutoInstrumentations({
          '@opentelemetry/instrumentation-http': {
            enabled: true,
            ignoreOutgoingUrls: [/\/v1\/traces$/, /\/v1\/metrics$/],
          },
          '@opentelemetry/instrumentation-express': {
            enabled: true,
          },
        }),
        new ExpressInstrumentation(),
        new HttpInstrumentation(),
      ],
      spanProcessor: new opentelemetry.tracing.BatchSpanProcessor(traceExporter, {
        maxQueueSize: 2048,
        scheduledDelayMillis: 5000,
      }),
    })

    try {
      const startResult = sdk.start()
      if (startResult && typeof startResult.then === 'function') {
        startResult
          .then(() => {
            span.addEvent('opentelemetry_sdk_started')
            span.setStatus({ code: SpanStatusCode.OK })
          })
          .catch((error) => {
            span.addEvent('opentelemetry_sdk_start_error', {
              attributes: {
                error: error.message,
                stack: error.stack,
              },
            })
            span.setStatus({
              code: SpanStatusCode.ERROR,
              message: error.message,
            })
          })
      }
      else {
        span.addEvent('opentelemetry_sdk_started')
        span.setStatus({ code: SpanStatusCode.OK })
      }
    }
    catch (error) {
      span.addEvent('opentelemetry_sdk_start_error', {
        attributes: {
          error: error.message,
          stack: error.stack,
        },
      })
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      })
    }

    process.on('SIGTERM', () => {
      const shutdownSpan = tracer.startSpan('shutdown_telemetry')
      try {
        shutdownSpan.addEvent('shutting_down_opentelemetry')
        const shutdownResult = sdk.shutdown()
        if (shutdownResult && typeof shutdownResult.then === 'function') {
          shutdownResult
            .then(() => {
              shutdownSpan.addEvent('opentelemetry_terminated')
              shutdownSpan.setStatus({ code: SpanStatusCode.OK })
              shutdownSpan.end()
              process.exit(0)
            })
            .catch((error) => {
              shutdownSpan.addEvent('opentelemetry_termination_error', {
                attributes: {
                  error: error.message,
                  stack: error.stack,
                },
              })
              shutdownSpan.setStatus({
                code: SpanStatusCode.ERROR,
                message: error.message,
              })
              shutdownSpan.end()
              process.exit(1)
            })
        }
        else {
          shutdownSpan.addEvent('opentelemetry_terminated')
          shutdownSpan.setStatus({ code: SpanStatusCode.OK })
          shutdownSpan.end()
          process.exit(0)
        }
      }
      catch (error) {
        shutdownSpan.addEvent('opentelemetry_shutdown_error', {
          attributes: {
            error: error.message,
            stack: error.stack,
          },
        })
        shutdownSpan.setStatus({
          code: SpanStatusCode.ERROR,
          message: error.message,
        })
        shutdownSpan.end()
        process.exit(1)
      }
    })
  }
  catch (error) {
    span.addEvent('opentelemetry_initialization_error', {
      attributes: {
        error: error.message,
        stack: error.stack,
      },
    })
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    })
  }
  finally {
    span.end()
  }
}

export { setupTelemetry }
