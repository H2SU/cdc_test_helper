#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
OUTPUT_DIR=${1:-"$SCRIPT_DIR/dist"}

detect_cubrid_home()
{
  if [[ -n "${CUBRID:-}" ]]; then
    printf '%s\n' "$CUBRID"
    return
  fi

  local cubrid_command
  cubrid_command=$(command -v cubrid 2>/dev/null || true)
  if [[ -z "$cubrid_command" ]]; then
    return 1
  fi

  cubrid_command=$(readlink -f "$cubrid_command")
  cd -- "$(dirname -- "$cubrid_command")/.." && pwd -P
}

find_library()
{
  local library_name=$1
  local candidate

  for candidate in "$CUBRID_HOME/lib/$library_name" "$CUBRID_HOME/cci/lib/$library_name"; do
    if [[ -e "$candidate" ]]; then
      readlink -f "$candidate"
      return
    fi
  done

  return 1
}

CUBRID_HOME=$(detect_cubrid_home || true)
if [[ -z "$CUBRID_HOME" ]]; then
  echo "[ERROR] CUBRID 설치 경로를 찾을 수 없습니다."
  exit 1
fi

LIBCUBRIDCS=$(find_library libcubridcs.so.11.4 || true)
LIBCASCCI=$(find_library libcascci.so.11.2 || true)
if [[ -z "$LIBCUBRIDCS" || -z "$LIBCASCCI" ]]; then
  echo "[ERROR] CUBRID 11.4 CDC/CCI 라이브러리를 찾을 수 없습니다."
  echo "        CUBRID=$CUBRID_HOME"
  exit 1
fi

if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  VERSION=${PACKAGE_VERSION:-$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)}
else
  VERSION=${PACKAGE_VERSION:-$(date +%Y%m%d)}
fi

PACKAGE_NAME="cdc_test_helper-${VERSION}-linux-x86_64"
STAGING_ROOT=$(mktemp -d)
PACKAGE_DIR="$STAGING_ROOT/$PACKAGE_NAME"
ARCHIVE_PATH="$OUTPUT_DIR/$PACKAGE_NAME.tar.gz"

cleanup()
{
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

CDC_TEST_HELPER_RELEASE_BUILD=1 CDC_TEST_HELPER_RPATH='$ORIGIN/lib' "$SCRIPT_DIR/build.sh"

mkdir -p "$PACKAGE_DIR/lib" "$OUTPUT_DIR"
cp "$SCRIPT_DIR/cdc_test_helper" "$PACKAGE_DIR/cdc_test_helper"
cp "$SCRIPT_DIR/cdc_test_helper.conf" "$PACKAGE_DIR/cdc_test_helper.conf"
cp "$SCRIPT_DIR/README.md" "$PACKAGE_DIR/README.md"
cp "$SCRIPT_DIR/LICENSE" "$PACKAGE_DIR/LICENSE"
cp "$SCRIPT_DIR/install_binary.sh" "$PACKAGE_DIR/install.sh"
cp "$LIBCUBRIDCS" "$PACKAGE_DIR/lib/libcubridcs.so.11.4"
cp "$LIBCASCCI" "$PACKAGE_DIR/lib/libcascci.so.11.2"

chmod 755 "$PACKAGE_DIR/cdc_test_helper" "$PACKAGE_DIR/install.sh" "$PACKAGE_DIR/lib/"*.so.*
chmod 600 "$PACKAGE_DIR/cdc_test_helper.conf"
chmod 644 "$PACKAGE_DIR/README.md" "$PACKAGE_DIR/LICENSE"

if command -v strip >/dev/null 2>&1; then
  strip --strip-unneeded "$PACKAGE_DIR/cdc_test_helper" "$PACKAGE_DIR/lib/"*.so.*
fi

cat >"$PACKAGE_DIR/PACKAGE_INFO" <<EOF
package_name=$PACKAGE_NAME
architecture=linux-x86_64
cubrid_client_version=11.4.5
EOF
chmod 644 "$PACKAGE_DIR/PACKAGE_INFO"

(
  cd "$PACKAGE_DIR"
  sha256sum cdc_test_helper cdc_test_helper.conf lib/libcubridcs.so.11.4 lib/libcascci.so.11.2 >SHA256SUMS
  chmod 644 SHA256SUMS
)

tar --owner=0 --group=0 --numeric-owner -C "$STAGING_ROOT" -czf "$ARCHIVE_PATH" "$PACKAGE_NAME"
(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE_PATH")" >"$(basename "$ARCHIVE_PATH").sha256"
)

echo "[OK] 바이너리 패키지 생성 완료"
echo "[OK] 패키지: $ARCHIVE_PATH"
echo "[OK] 체크섬: $ARCHIVE_PATH.sha256"
