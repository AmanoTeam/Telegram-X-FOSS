#!/bin/bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TD_DIR="$ROOT/td"
BUILD_DIR="$TD_DIR/prebuild"

if [ ! -d "$TD_DIR/td/generate" ]; then
  echo -e "${STYLE_ERROR}Failed! td submodule not checked out at $TD_DIR${STYLE_END}"
  echo -e "${STYLE_ERROR}Try: git submodule update --init td${STYLE_END}"
  exit 1
fi

test "$CPU_COUNT" || CPU_COUNT="$(nproc --all 2>/dev/null || echo 4)"

# Prerequisites: cmake and a JDK (find_package(JNI)/find_package(Java) in the
# patched CMakeLists.txt), gperf (tdutils MIME generation during
# prepare_cross_compiling), and OpenSSL/zlib dev (so CMake doesn't return early
# and the TD_BUILD_JAVA block at the end of the file defining the targets).
if ! command -v cmake >/dev/null 2>&1; then
  echo -e "${STYLE_ERROR}Failed! cmake not found on PATH.${STYLE_END}"
  exit 1
fi
if ! command -v gperf >/dev/null 2>&1; then
  echo -e "${STYLE_ERROR}Failed! gperf not found on PATH (required by tdutils MIME generation).${STYLE_END}"
  echo -e "${STYLE_ERROR}Install it, e.g. 'apt-get install gperf'${STYLE_END}"
  exit 1
fi
if [ -z "$JAVA_HOME" ]; then
  if command -v javac >/dev/null 2>&1; then
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
  else
    echo -e "${STYLE_ERROR}Failed! No JDK found: JAVA_HOME unset and javac not on PATH.${STYLE_END}"
    exit 1
  fi
fi
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

if command -v pkg-config >/dev/null 2>&1; then
  if ! pkg-config --exists openssl; then
    echo -e "${STYLE_ERROR}Failed! OpenSSL dev files not found by pkg-config (CMake requires OpenSSL to reach the Java targets).${STYLE_END}"
    echo -e "${STYLE_ERROR}Install them, e.g. 'apt-get install libssl-dev'${STYLE_END}"
    exit 1
  fi
  if ! pkg-config --exists zlib; then
    echo -e "${STYLE_ERROR}Failed! zlib dev files not found by pkg-config (CMake requires zlib to reach the Java targets).${STYLE_END}"
    echo -e "${STYLE_ERROR}Install them, e.g. 'apt-get install zlib1g-dev'${STYLE_END}"
    exit 1
  fi
fi

echo -e "${STYLE_INFO}- td prebuild: configuring host build for Java TDLib API generation${STYLE_END}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cmake -S "$TD_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DTD_BUILD_JAVA=ON \
  -DTD_ENABLE_JNI=ON

echo -e "${STYLE_INFO}- td prebuild: building host generators (prepare_cross_compiling)${STYLE_END}"
cmake --build "$BUILD_DIR" --target prepare_cross_compiling --parallel "$CPU_COUNT"

echo -e "${STYLE_INFO}- td prebuild: generating Java TDLib API sources (td_generate_java_api_files)${STYLE_END}"
cmake --build "$BUILD_DIR" --target td_generate_java_api_files --parallel "$CPU_COUNT"

echo -e "${STYLE_INFO}- td prebuild done! Generated sources in $TD_DIR/example/java/org/drinkless/tdlib/${STYLE_END}"
