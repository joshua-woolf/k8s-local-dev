FROM node:20.11-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

FROM node:20.11-alpine

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV=production
ENV OTEL_SERVICE_NAME=k8s-dashboard
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318
ENV OTEL_TRACES_SAMPLER=parentbased_traceidratio
ENV OTEL_TRACES_SAMPLER_ARG=1
ENV OTEL_PROPAGATORS=tracecontext,baggage
ENV OTEL_METRICS_EXPORTER=otlp
ENV OTEL_LOGS_EXPORTER=otlp

USER node
EXPOSE 3000
CMD ["npm", "start"]
