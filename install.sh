#!/usr/bin/env sh
# Campfire 최초 설치 스크립트
set -eu

RELEASE_REPO="SUSUSISI/campfire-releases"
INSTALL_PATH="/Applications/Campfire.app"
DOWNLOAD_URL="https://github.com/$RELEASE_REPO/releases/latest/download/Campfire.dmg"
TMP_DIR=$(mktemp -d)
DMG_PATH="$TMP_DIR/Campfire.dmg"

trap 'rm -rf "$TMP_DIR"' EXIT

echo "Campfire 설치를 시작합니다..."

# macOS 14 이상 확인
OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$OS_MAJOR" -lt 14 ]; then
    echo "오류: macOS 14 (Sonoma) 이상이 필요합니다."
    exit 1
fi

# DMG 다운로드
echo "최신 버전 다운로드 중..."
if ! curl -fL --progress-bar "$DOWNLOAD_URL" -o "$DMG_PATH" 2>&1; then
    echo "오류: 다운로드에 실패했습니다. 네트워크 상태를 확인하세요."
    exit 1
fi

# 마운트 및 설치
echo "설치 중..."
MOUNT_OUT=$(hdiutil attach "$DMG_PATH" -nobrowse -noautoopen 2>/dev/null)
MOUNT_POINT=$(echo "$MOUNT_OUT" | awk '/\/Volumes/ {print $NF}')

if [ -z "$MOUNT_POINT" ]; then
    echo "오류: DMG 마운트에 실패했습니다."
    exit 1
fi

if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

ditto "$MOUNT_POINT/Campfire.app" "$INSTALL_PATH"
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
xattr -d com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true
codesign --force --deep --sign - "$INSTALL_PATH" >/dev/null 2>&1

echo ""
echo "설치 완료!"
echo ""

# 권한 안내
echo "Campfire는 아래 두 가지 권한이 필요합니다."
echo "각 항목에서 Campfire를 찾아 허용해 주세요."
echo ""

echo "[1/2] 손쉬운 사용 (Accessibility)"
echo "  전역 단축키(퀵팔레트, 위젯 토글 등) 사용에 필요합니다."
printf "  System Settings를 여시겠습니까? [Y/n] "
read -r yn
case "${yn:-Y}" in
    [Nn]*) ;;
    *) open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" ;;
esac

echo ""
echo "[2/2] 입력 모니터링 (Input Monitoring)"
echo "  키보드·마우스 활동 감지로 presence 상태를 변경합니다."
printf "  System Settings를 여시겠습니까? [Y/n] "
read -r yn
case "${yn:-Y}" in
    [Nn]*) ;;
    *) open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" ;;
esac

echo ""
echo "권한을 허용한 후 Campfire를 시작합니다..."
open "$INSTALL_PATH"
