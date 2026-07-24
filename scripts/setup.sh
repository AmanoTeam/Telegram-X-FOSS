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
  echo -e "${STYLE_INFO}local.properties already exists.${STYLE_END}"
fi

# == Setup thirdparty libraries ==

patch-opusfile-impl.sh

# Patch missing standard-library includes required by gcc (stricter than clang)
patch-gcc-includes-impl.sh

# == Copy local.properties ===

if [[ ! -f local.properties ]]; then
  cat > local.properties <<EOF
sdk.dir=$ANDROID_SDK_ROOT
org.gradle.workers.max=$CPU_COUNT
EOF
fi

echo -e "${STYLE_INFO}Configure finished!${STYLE_END}"

