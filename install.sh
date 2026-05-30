#!/usr/bin/env sh
# Campfire 최초 설치 스크립트
set -eu

RELEASE_REPO="SUSUSISI/campfire-releases"
INSTALL_PATH="/Applications/Campfire.app"
DOWNLOAD_URL="https://github.com/$RELEASE_REPO/releases/latest/download/Campfire.dmg"
TMP_DIR=$(mktemp -d)
DMG_PATH="$TMP_DIR/Campfire.dmg"
MOUNT_POINT="$TMP_DIR/mount"

cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

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
mkdir -p "$MOUNT_POINT"

if ! hdiutil attach "$DMG_PATH" -nobrowse -noautoopen -mountpoint "$MOUNT_POINT" >/dev/null 2>&1; then
    echo "오류: DMG 마운트에 실패했습니다."
    exit 1
fi

if pgrep -x Campfire >/dev/null 2>&1; then
    echo "실행 중인 Campfire를 종료합니다..."
    osascript -e 'tell application "Campfire" to quit' >/dev/null 2>&1 || true
    sleep 1
fi

if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

ditto "$MOUNT_POINT/Campfire.app" "$INSTALL_PATH"

# 터미널 설치는 사용자가 명시적으로 실행한 경로이므로 quarantine을 제거해
# 최초 실행 시 Gatekeeper의 미인증 개발자 차단을 피한다.
xattr -d com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || true)

echo ""
if [ -n "$INSTALLED_VERSION" ]; then
    echo "설치 완료! (v$INSTALLED_VERSION)"
else
    echo "설치 완료!"
fi
echo ""

open "$INSTALL_PATH"
