# Local Valkey Admin image

Valkey Admin's supported `VITE_LOCAL_VALKEY_*` settings are build-time values,
so the published image cannot add a connection card from runtime environment
variables. This small derivative rebuilds the frontend from the pinned 1.0.1
source commit and names the connection `Local Valkey`.

The frontend deliberately receives no password. The accompanying server patch
recognizes only that exact internal host and port, then injects the generated
Kubernetes Secret before opening the upstream connection. This keeps the
password out of the image and browser JavaScript while allowing a fresh browser
profile to connect automatically.

When updating Valkey Admin, update the source commit, archive checksum, base
image digest, patch, and local image tag together. Verify the result with
`make validate`, `make valkey-admin-image`, and `make smoke`.
