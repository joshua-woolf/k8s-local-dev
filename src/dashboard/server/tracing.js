const opentelemetry = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-proto');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-proto');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');

function setupTelemetry() {
  try {
    console.log('Initializing OpenTelemetry...');

    const resource = new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'dashboard',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development'
    });

    const commonExporterConfig = {
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
      timeoutMillis: 30000,
      concurrencyLimit: 10,
    };

    console.log('OTLP Endpoint:', commonExporterConfig.url);

    const traceExporter = new OTLPTraceExporter({
      ...commonExporterConfig,
      url: `${commonExporterConfig.url}/v1/traces`
    });

    const metricExporter = new OTLPMetricExporter({
      ...commonExporterConfig,
      url: `${commonExporterConfig.url}/v1/metrics`
    });

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
    });

    try {
      const startResult = sdk.start();
      if (startResult && typeof startResult.then === 'function') {
        startResult
          .then(() => {
            console.log('OpenTelemetry SDK started successfully');
          })
          .catch((error) => {
            console.error('Error starting OpenTelemetry SDK:', error);
          });
      } else {
        console.log('OpenTelemetry SDK started successfully');
      }
    } catch (error) {
      console.error('Error starting OpenTelemetry SDK:', error);
    }

    process.on('SIGTERM', () => {
      console.log('Shutting down OpenTelemetry...');
      try {
        const shutdownResult = sdk.shutdown();
        if (shutdownResult && typeof shutdownResult.then === 'function') {
          shutdownResult
            .then(() => {
              console.log('OpenTelemetry terminated successfully');
              process.exit(0);
            })
            .catch((error) => {
              console.error('Error terminating OpenTelemetry:', error);
              process.exit(1);
            });
        } else {
          console.log('OpenTelemetry terminated successfully');
          process.exit(0);
        }
      } catch (error) {
        console.error('Error shutting down OpenTelemetry:', error);
        process.exit(1);
      }
    });
  } catch (error) {
    console.error('Error initializing OpenTelemetry:', error);
  }
}

module.exports = { setupTelemetry };
