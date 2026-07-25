#!/bin/bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

apply_patch() {
  local dir="$1"
  local input="$2"

  if [ ! -d "$dir" ]; then
    echo "Skipping $(basename "$input") (target directory not found: $dir)"
    return 0
  fi

  if patch \
      --directory="$dir" \
      --strip=1 \
      --forward \
      --dry-run \
      --input="$input" >/dev/null 2>&1; then
    echo "Applying $(basename "$input")"
    patch \
        --directory="$dir" \
        --strip=1 \
        --forward \
        --input="$input"
  else
    echo "Skipping $(basename "$input") (already applied or not applicable)"
  fi
}

apply_patch \
    "${ROOT}/app/jni/tgvoip/third_party/libsrtp" \
    "${ROOT}/libsrtp-patches/0001-Use-opaque-HMAC-and-EVP_MD_CTX-for-LibreSSL-3.0.patch"

echo "libsrtp patches applied successfully!"
