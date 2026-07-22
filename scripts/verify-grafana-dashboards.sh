#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dashboard_root="${repo_root}/manifests/observability/dashboards"
sources_file="${dashboard_root}/sources.json"

find "${dashboard_root}" -mindepth 2 -name '*.json' -print0 | xargs -0 jq empty

while IFS=$'\t' read -r relative_path expected_hash; do
  actual_hash="$(shasum -a 256 "${dashboard_root}/${relative_path}" | awk '{print $1}')"
  if [[ "${actual_hash}" != "${expected_hash}" ]]; then
    echo "Dashboard checksum mismatch: ${relative_path}" >&2
    echo "Expected ${expected_hash}, got ${actual_hash}" >&2
    exit 1
  fi
done < <(jq -r '.dashboards[] | [.file, .sha256] | @tsv' "${sources_file}")
