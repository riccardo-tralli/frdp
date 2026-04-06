#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CACHE_DIR="${MACOS_DIR}/.freerdp"
SOURCE_DIR="${CACHE_DIR}/source"
BUILD_DIR="${CACHE_DIR}/build"
INSTALL_DIR="${CACHE_DIR}/install"
THIRD_PARTY_DIR="${CACHE_DIR}/third_party"
DEPS_INSTALL_DIR="${CACHE_DIR}/deps/install"
OPENSSL_SRC_DIR="${THIRD_PARTY_DIR}/openssl"
JANSSON_SRC_DIR="${THIRD_PARTY_DIR}/jansson"
JANSSON_BUILD_DIR="${CACHE_DIR}/deps/build/jansson"
STAMP_FILE="${INSTALL_DIR}/.frdp-build-stamp"
HOST_ARCH="$(uname -m)"

FREERDP_GIT_URL="${FREERDP_GIT_URL:-https://github.com/FreeRDP/FreeRDP.git}"
FREERDP_GIT_REF="${FREERDP_GIT_REF:-3.24.2}"
FREERDP_ARCH="${FREERDP_ARCH:-${HOST_ARCH}}"
FRDP_MACOS_DEPLOYMENT_TARGET="${FRDP_MACOS_DEPLOYMENT_TARGET:-${MACOSX_DEPLOYMENT_TARGET:-10.15}}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.2}"
JANSSON_GIT_URL="${JANSSON_GIT_URL:-https://github.com/akheron/jansson.git}"
JANSSON_GIT_REF="${JANSSON_GIT_REF:-v2.14}"
OPENSSL_PREFIX="${DEPS_INSTALL_DIR}"
JANSSON_PREFIX="${DEPS_INSTALL_DIR}"
FRDP_BUILD_PROFILE_VERSION="1"
BUILD_SIGNATURE=$(cat <<EOF
freerdp_git_url=${FREERDP_GIT_URL}
freerdp_git_ref=${FREERDP_GIT_REF}
freerdp_arch=${FREERDP_ARCH}
macos_deployment_target=${FRDP_MACOS_DEPLOYMENT_TARGET}
build_profile_version=${FRDP_BUILD_PROFILE_VERSION}
openssl_version=${OPENSSL_VERSION}
jansson_git_url=${JANSSON_GIT_URL}
jansson_git_ref=${JANSSON_GIT_REF}
EOF
)

IFS=';' read -r -a ARCH_ARRAY <<< "${FREERDP_ARCH}"
if [[ "${#ARCH_ARRAY[@]}" -ne 1 ]]; then
  cat >&2 <<'EOF'
[frdp] ERROR: embedded OpenSSL/Jansson build currently supports one architecture at a time.
[frdp] Set FREERDP_ARCH to a single value (for example: arm64 or x86_64).
EOF
  exit 1
fi
BUILD_ARCH="${ARCH_ARRAY[0]}"

openssl_target_for_arch() {
  case "$1" in
    arm64)
      echo "darwin64-arm64-cc"
      ;;
    x86_64)
      echo "darwin64-x86_64-cc"
      ;;
    *)
      return 1
      ;;
  esac
}

openssl_lib_present() {
  [[ -f "${OPENSSL_PREFIX}/lib/libcrypto.a" ]] || [[ -f "${OPENSSL_PREFIX}/lib/libcrypto.dylib" ]]
}

jansson_lib_present() {
  [[ -f "${JANSSON_PREFIX}/lib/libjansson.a" ]] || [[ -f "${JANSSON_PREFIX}/lib/libjansson.dylib" ]]
}

if ! command -v git >/dev/null 2>&1; then
  echo "[frdp] ERROR: git is required to clone FreeRDP." >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[frdp] ERROR: cmake is required to build embedded FreeRDP.
[frdp] Install it (and optionally ninja) with your preferred package manager,
[frdp] then re-run pod install/build.
EOF
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[frdp] ERROR: curl is required to download OpenSSL sources." >&2
  exit 1
fi

if ! command -v perl >/dev/null 2>&1; then
  echo "[frdp] ERROR: perl is required to build embedded OpenSSL." >&2
  exit 1
fi

if ! command -v make >/dev/null 2>&1; then
  echo "[frdp] ERROR: make is required to build embedded OpenSSL." >&2
  exit 1
fi

needs_build="1"
if [[ -f "${STAMP_FILE}" ]] && [[ -f "${INSTALL_DIR}/lib/libfreerdp3.a" ]] && openssl_lib_present && jansson_lib_present; then
  if [[ "$(cat "${STAMP_FILE}")" == "${BUILD_SIGNATURE}" ]]; then
    needs_build="0"
  fi
fi

if [[ "${needs_build}" == "0" ]]; then
  echo "[frdp] Embedded FreeRDP already available at ${INSTALL_DIR}"
  exit 0
fi

mkdir -p "${CACHE_DIR}"
mkdir -p "${THIRD_PARTY_DIR}"

OPENSSL_TARGET="$(openssl_target_for_arch "${BUILD_ARCH}" || true)"
if [[ -z "${OPENSSL_TARGET}" ]]; then
  echo "[frdp] ERROR: unsupported architecture '${BUILD_ARCH}' for embedded OpenSSL." >&2
  exit 1
fi

if ! openssl_lib_present; then
  echo "[frdp] Building embedded OpenSSL ${OPENSSL_VERSION} (${BUILD_ARCH})"
  rm -rf "${OPENSSL_SRC_DIR}" "${DEPS_INSTALL_DIR}"
  mkdir -p "${THIRD_PARTY_DIR}" "${DEPS_INSTALL_DIR}"

  curl -L "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" -o "${THIRD_PARTY_DIR}/openssl-${OPENSSL_VERSION}.tar.gz"
  tar -xzf "${THIRD_PARTY_DIR}/openssl-${OPENSSL_VERSION}.tar.gz" -C "${THIRD_PARTY_DIR}"
  mv "${THIRD_PARTY_DIR}/openssl-${OPENSSL_VERSION}" "${OPENSSL_SRC_DIR}"

  (
    cd "${OPENSSL_SRC_DIR}"
    ./Configure "${OPENSSL_TARGET}" no-shared no-tests no-module enable-legacy enable-weak-ssl-ciphers --prefix="${OPENSSL_PREFIX}" --openssldir="${OPENSSL_PREFIX}/ssl" "-mmacosx-version-min=${FRDP_MACOS_DEPLOYMENT_TARGET}"
    make -j"$(sysctl -n hw.ncpu)"
    make install_sw
  )
fi

if ! jansson_lib_present; then
  echo "[frdp] Building embedded jansson ${JANSSON_GIT_REF} (${BUILD_ARCH})"
  rm -rf "${JANSSON_BUILD_DIR}"
  mkdir -p "${CACHE_DIR}/deps/build"

  if [[ ! -d "${JANSSON_SRC_DIR}/.git" ]]; then
    git clone --recurse-submodules "${JANSSON_GIT_URL}" "${JANSSON_SRC_DIR}"
  fi
  git -C "${JANSSON_SRC_DIR}" fetch --depth 1 --force origin "${JANSSON_GIT_REF}"
  git -C "${JANSSON_SRC_DIR}" checkout --force FETCH_HEAD

  if command -v ninja >/dev/null 2>&1; then
    cmake -G Ninja "${JANSSON_SRC_DIR}" \
      -B "${JANSSON_BUILD_DIR}" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_INSTALL_PREFIX="${JANSSON_PREFIX}" \
      -DCMAKE_OSX_ARCHITECTURES="${FREERDP_ARCH}" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="${FRDP_MACOS_DEPLOYMENT_TARGET}" \
      -DBUILD_SHARED_LIBS=OFF \
      -DJANSSON_BUILD_DOCS=OFF \
      -DJANSSON_EXAMPLES=OFF \
      -DJANSSON_WITHOUT_TESTS=ON
  else
    cmake "${JANSSON_SRC_DIR}" \
      -B "${JANSSON_BUILD_DIR}" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_INSTALL_PREFIX="${JANSSON_PREFIX}" \
      -DCMAKE_OSX_ARCHITECTURES="${FREERDP_ARCH}" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="${FRDP_MACOS_DEPLOYMENT_TARGET}" \
      -DBUILD_SHARED_LIBS=OFF \
      -DJANSSON_BUILD_DOCS=OFF \
      -DJANSSON_EXAMPLES=OFF \
      -DJANSSON_WITHOUT_TESTS=ON
  fi
  cmake --build "${JANSSON_BUILD_DIR}" --config Release --parallel
  cmake --install "${JANSSON_BUILD_DIR}" --config Release
fi

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  echo "[frdp] Cloning FreeRDP from ${FREERDP_GIT_URL}"
  git clone --recurse-submodules "${FREERDP_GIT_URL}" "${SOURCE_DIR}"
fi

echo "[frdp] Refreshing FreeRDP source to ${FREERDP_GIT_REF}"
git -C "${SOURCE_DIR}" fetch --depth 1 --force origin "${FREERDP_GIT_REF}"
git -C "${SOURCE_DIR}" checkout --force FETCH_HEAD
git -C "${SOURCE_DIR}" submodule sync --recursive
git -C "${SOURCE_DIR}" submodule update --init --recursive

rm -rf "${BUILD_DIR}" "${INSTALL_DIR}"
mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"

echo "[frdp] Configuring FreeRDP (${FREERDP_ARCH})"
PKG_CONFIG_PATH_VALUE="${JANSSON_PREFIX}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
if command -v ninja >/dev/null 2>&1; then
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH_VALUE}" cmake -GNinja "${SOURCE_DIR}" \
    -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_PREFIX_PATH="${OPENSSL_PREFIX};${JANSSON_PREFIX}" \
    -DOPENSSL_ROOT_DIR="${OPENSSL_PREFIX}" \
    -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DCMAKE_OSX_ARCHITECTURES="${FREERDP_ARCH}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${FRDP_MACOS_DEPLOYMENT_TARGET}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_VERBOSE_WINPR_ASSERT=OFF \
    -DWITH_CLIENT=OFF \
    -DWITH_CLIENT_COMMON=ON \
    -DWITH_CLIENT_CHANNELS=ON \
    -DWITH_CLIENT_SDL=OFF \
    -DWITH_CHANNELS=ON \
    -DWITH_SERVER=OFF \
    -DWITH_WINPR_TOOLS=OFF \
    -DWITH_SAMPLE=OFF \
    -DWITH_MANPAGES=OFF \
    -DWITH_OPUS=OFF \
    -DWITH_AAD=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_DSP_FFMPEG=OFF \
    -DWITH_VIDEO_FFMPEG=OFF \
    -DWITH_SWSCALE=OFF \
    -DWITH_CAIRO=OFF \
    -DWITH_CUPS=OFF \
    -DWITH_PULSE=OFF \
    -DWITH_ALSA=OFF \
    -DWITH_PCSC=OFF \
    -DWITH_GSSAPI=OFF \
    -DWITH_X11=OFF \
    -DWITH_XCURSOR=OFF \
    -DWITH_XINERAMA=OFF \
    -DWITH_XEXT=OFF \
    -DWITH_XKBFILE=OFF \
    -DWITH_WAYLAND=OFF \
    -DCHANNEL_AINPUT=OFF \
    -DCHANNEL_AUDIN=OFF \
    -DCHANNEL_DISP=OFF \
    -DCHANNEL_DRIVE=OFF \
    -DCHANNEL_ECHO=OFF \
    -DCHANNEL_ENCOMSP=OFF \
    -DCHANNEL_GEOMETRY=OFF \
    -DCHANNEL_LOCATION=OFF \
    -DCHANNEL_PARALLEL=OFF \
    -DCHANNEL_PRINTER=OFF \
    -DCHANNEL_RAIL=OFF \
    -DCHANNEL_REMDESK=OFF \
    -DCHANNEL_RDPEI=OFF \
    -DCHANNEL_SERIAL=OFF \
    -DCHANNEL_SMARTCARD=OFF \
    -DCHANNEL_URBDRC=OFF \
    -DCHANNEL_VIDEO=OFF
else
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH_VALUE}" cmake "${SOURCE_DIR}" \
    -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_PREFIX_PATH="${OPENSSL_PREFIX};${JANSSON_PREFIX}" \
    -DOPENSSL_ROOT_DIR="${OPENSSL_PREFIX}" \
    -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DCMAKE_OSX_ARCHITECTURES="${FREERDP_ARCH}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${FRDP_MACOS_DEPLOYMENT_TARGET}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_VERBOSE_WINPR_ASSERT=OFF \
    -DWITH_CLIENT=OFF \
    -DWITH_CLIENT_COMMON=ON \
    -DWITH_CLIENT_CHANNELS=ON \
    -DWITH_CLIENT_SDL=OFF \
    -DWITH_CHANNELS=ON \
    -DWITH_SERVER=OFF \
    -DWITH_WINPR_TOOLS=OFF \
    -DWITH_SAMPLE=OFF \
    -DWITH_MANPAGES=OFF \
    -DWITH_OPUS=OFF \
    -DWITH_AAD=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_DSP_FFMPEG=OFF \
    -DWITH_VIDEO_FFMPEG=OFF \
    -DWITH_SWSCALE=OFF \
    -DWITH_CAIRO=OFF \
    -DWITH_CUPS=OFF \
    -DWITH_PULSE=OFF \
    -DWITH_ALSA=OFF \
    -DWITH_PCSC=OFF \
    -DWITH_GSSAPI=OFF \
    -DWITH_X11=OFF \
    -DWITH_XCURSOR=OFF \
    -DWITH_XINERAMA=OFF \
    -DWITH_XEXT=OFF \
    -DWITH_XKBFILE=OFF \
    -DWITH_WAYLAND=OFF \
    -DCHANNEL_AINPUT=OFF \
    -DCHANNEL_AUDIN=OFF \
    -DCHANNEL_DISP=OFF \
    -DCHANNEL_DRIVE=OFF \
    -DCHANNEL_ECHO=OFF \
    -DCHANNEL_ENCOMSP=OFF \
    -DCHANNEL_GEOMETRY=OFF \
    -DCHANNEL_LOCATION=OFF \
    -DCHANNEL_PARALLEL=OFF \
    -DCHANNEL_PRINTER=OFF \
    -DCHANNEL_RAIL=OFF \
    -DCHANNEL_REMDESK=OFF \
    -DCHANNEL_RDPEI=OFF \
    -DCHANNEL_SERIAL=OFF \
    -DCHANNEL_SMARTCARD=OFF \
    -DCHANNEL_URBDRC=OFF \
    -DCHANNEL_VIDEO=OFF
fi

echo "[frdp] Building and installing FreeRDP"
cmake --build "${BUILD_DIR}" --config Release --parallel
cmake --install "${BUILD_DIR}" --config Release

echo "${BUILD_SIGNATURE}" > "${STAMP_FILE}"

echo "[frdp] Embedded FreeRDP ready at ${INSTALL_DIR}"
