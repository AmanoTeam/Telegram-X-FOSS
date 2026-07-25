#!/bin/bash
set -e

# == Setup SDK & NDK ==
if [[ "$1" == "--skip-sdk-setup" ]]; then
  # shellcheck source=set-env.sh
  source "$(pwd)/scripts/set-env.sh"
else
  # shellcheck source=setup-sdk.sh
  source "$(pwd)/scripts/setup-sdk.sh"
fi

if [[ -f local.properties ]]; then
  echo -e "${STYLE_INFO}local.properties already exists. Cleaning...${STYLE_END}"
  reset.sh
fi

# == Setup thirdparty libraries ==

if [ "$WIN_PATCH_REQUIRED" = true ]; then
  patch-windows-impl.sh
fi

# Patch opus
patch-opus-impl.sh

# Patch androidx-media sources
patch-androidx-media-impl.sh

patch-rlottie-and-opusfile-impl.sh

# Patch missing standard-library includes required by gcc (stricter than clang)
patch-gcc-includes-impl.sh

# Patch td submodule: add TD_BUILD_JAVA / TD_JSON_JAVA options and Java JNI example build
patch-td-impl.sh

# Patch libsrtp: use opaque HMAC_CTX / EVP_MD_CTX for LibreSSL 3.0+ (bundled copy is pinned to the legacy-API path)
patch-libsrtp-impl.sh

# Prebuild td: generate Java TDLib API sources (host build via TD_BUILD_JAVA)
build-td-impl.sh

# Build and configure libvpx
build-vpx-impl.sh

# Build and configure ffmpeg
build-ffmpeg-impl.sh

# == Copy local.properties ===

if [[ ! -f local.properties ]]; then
  cat > local.properties <<EOF
sdk.dir=$ANDROID_SDK_ROOT
org.gradle.workers.max=$CPU_COUNT
EOF
fi

echo -e "${STYLE_INFO}Configure finished!${STYLE_END}"

