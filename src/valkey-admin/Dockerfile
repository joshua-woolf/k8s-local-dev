FROM docker.io/library/node:22-bookworm-slim@sha256:6c74791e557ce11fc957704f6d4fe134a7bc8d6f5ca4403205b2966bd488f6b3 AS builder

WORKDIR /app

ADD --checksum=sha256:d01e4dffa16bff5d19bab17939c1aa3030ed2b43591f5c9d9f04737472860b9b https://github.com/valkey-io/valkey-admin/archive/9ba5e88b051184ce962d4624ce97e3dac14c1ea7.tar.gz /tmp/valkey-admin.tar.gz
COPY preconfigured-local-connection.patch /tmp/preconfigured-local-connection.patch

RUN apt-get update \
    && apt-get install --yes --no-install-recommends patch \
    && rm -rf /var/lib/apt/lists/* \
    && tar --extract --gzip --file /tmp/valkey-admin.tar.gz --strip-components=1 \
    && patch --strip=1 < /tmp/preconfigured-local-connection.patch

ENV VITE_LOCAL_VALKEY_HOST=valkey.data.svc.cluster.local
ENV VITE_LOCAL_VALKEY_PORT=6379
ENV VITE_LOCAL_VALKEY_NAME="Local Valkey"

RUN npm ci
RUN npm run build:all

FROM docker.io/valkey/valkey-admin:1.0.1@sha256:7d7b015c9964316b8eaa1660d0faec29e810d6be35cdafed4d86bd0c3d03acd7

LABEL org.opencontainers.image.source="https://github.com/valkey-io/valkey-admin"
LABEL org.opencontainers.image.version="1.0.1-local"

COPY --from=builder /app/apps/server/dist /app/apps/server/dist
COPY --from=builder /app/apps/frontend/dist /app/apps/frontend/dist
