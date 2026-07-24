#!/bin/bash
set -e

test "$THIRDPARTY_LIBRARIES" || (echo "\$THIRDPARTY_LIBRARIES is not set!" && exit 1)

ROOT="$(dirname "$(dirname "$(dirname "$THIRDPARTY_LIBRARIES")")")"

apply_patch() {
  local dir="$1"
  local input="$2"

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
    "${THIRDPARTY_LIBRARIES}/jni-utils" \
    "${THIRDPARTY_LIBRARIES}/jni-utils-patches/0001-Add-missing-cstring-cstdint-includes-for-gcc.patch"

apply_patch \
    "${ROOT}/vkryl/leveldb/jni/jni-utils" \
    "${ROOT}/vkryl/leveldb-patches/0001-Add-missing-cstring-cstdint-includes-for-gcc.patch"

apply_patch \
    "${ROOT}/app/jni/tgvoip/third_party/webrtc" \
    "${ROOT}/app/jni/tgvoip/third_party/webrtc-patches/0001-Add-missing-climits-for-gcc.patch"

apply_patch \
    "${ROOT}/app/jni/tgvoip/third_party/tgcalls" \
    "${ROOT}/app/jni/tgvoip/third_party/tgcalls-patches/0001-Add-missing-mutex-for-gcc.patch"

echo "gcc include patches applied successfully!"
