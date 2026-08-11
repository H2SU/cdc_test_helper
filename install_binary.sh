#!/usr/bin/env bash

set -euo pipefail

PACKAGE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
INSTALL_DIR=${CDC_TEST_HELPER_HOME:-"$HOME/.local/share/cdc_test_helper"}
USER_BIN_DIR=${HOME}/.local/bin

required_files=(
  cdc_test_helper
  cdc_test_helper.conf
  lib/libcubridcs.so.11.4
  lib/libcascci.so.11.2
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$PACKAGE_DIR/$required_file" ]]; then
    echo "[ERROR] 배포 파일이 없습니다: $PACKAGE_DIR/$required_file"
    exit 1
  fi
done

mkdir -p "$INSTALL_DIR/lib" "$USER_BIN_DIR"

install -m 755 "$PACKAGE_DIR/cdc_test_helper" "$INSTALL_DIR/cdc_test_helper"
install -m 755 "$PACKAGE_DIR/lib/libcubridcs.so.11.4" "$INSTALL_DIR/lib/libcubridcs.so.11.4"
install -m 755 "$PACKAGE_DIR/lib/libcascci.so.11.2" "$INSTALL_DIR/lib/libcascci.so.11.2"

if [[ ! -f "$INSTALL_DIR/cdc_test_helper.conf" ]]; then
  install -m 600 "$PACKAGE_DIR/cdc_test_helper.conf" "$INSTALL_DIR/cdc_test_helper.conf"
else
  echo "[NOTICE] 기존 설정 파일을 유지합니다: $INSTALL_DIR/cdc_test_helper.conf"
fi

for optional_file in README.md LICENSE PACKAGE_INFO; do
  if [[ -f "$PACKAGE_DIR/$optional_file" ]]; then
    install -m 644 "$PACKAGE_DIR/$optional_file" "$INSTALL_DIR/$optional_file"
  fi
done

ln -sfn "$INSTALL_DIR/cdc_test_helper" "$USER_BIN_DIR/cdc_test_helper"

echo
echo "[OK] 바이너리 설치 완료"
echo "[OK] 설치 경로: $INSTALL_DIR"
echo "[OK] 설정 파일: $INSTALL_DIR/cdc_test_helper.conf"
echo "[OK] 실행 명령: $USER_BIN_DIR/cdc_test_helper"
echo
echo "실행 전에 CUBRID와 CUBRID_DATABASES가 대상 DB 환경을 가리키는지 확인해 주세요."

case ":${PATH}:" in
  *":${USER_BIN_DIR}:"*) ;;
  *)
    echo "[NOTICE] $USER_BIN_DIR가 PATH에 없습니다. 다음 내용을 셸 설정 파일에 추가해 주세요."
    echo "         export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac
