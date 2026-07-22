FROM node:24-alpine@sha256:a0b9bf06e4e6193cf7a0f58816cc935ff8c2a908f81e6f1a95432d679c54fbfd

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server ./server

ENV NODE_ENV=production
ENV OTEL_SERVICE_NAME=dashboard
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc.cluster.local:4318
ENV OTEL_TRACES_SAMPLER=parentbased_traceidratio
ENV OTEL_TRACES_SAMPLER_ARG=1
ENV OTEL_PROPAGATORS=tracecontext,baggage
ENV OTEL_METRICS_EXPORTER=otlp

USER node
EXPOSE 3000
CMD ["node", "--import", "./server/tracing.js", "server/server.js"]
