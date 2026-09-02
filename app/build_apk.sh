#!/bin/bash
# APK 빌드. 루트 .env 에서 키를 읽어 --dart-define 으로 넘긴다.
#
# --dart-define 값은 빌드 시점에 코드로 컴파일된다.
# 그냥 flutter build apk 를 돌리면 지도 키가 빈 문자열이 되어
# 앱에서 "지도 키가 설정되지 않았습니다" 가 뜬다.
#
# 런처 아이콘은 assets/branding/app_icon_1024.png 를 기준으로
# flutter_launcher_icons 가 Android/iOS 네이티브 리소스를 생성한다.
#
# 사용:
#   ./build_apk.sh           디버그 (실기기 확인용)
#   ./build_apk.sh release   릴리스 (스토어 제출용, ABI 별로 분리)
set -e
cd "$(dirname "$0")"

if [ -f ../.env ]; then
  set -a
  . ../.env
  set +a
fi

if [ -z "${NAVER_MAP_CLIENT_ID}" ]; then
  echo "오류: NAVER_MAP_CLIENT_ID 가 비어 있습니다." >&2
  echo "      ~/petpass/.env 를 확인하세요. 지도 없는 APK 는 만들지 않습니다." >&2
  exit 1
fi

MODE="${1:-debug}"

# 릴리스는 CPU 아키텍처별로 나눈다.
# 하나로 합치면 모든 아키텍처가 들어가 용량이 세 배가 된다.
# Gradle 의 splits 블록은 Flutter 가 설정하는 ndk abiFilters 와 충돌하므로
# Flutter 가 제공하는 --split-per-abi 를 쓴다.
EXTRA=""
if [ "${MODE}" = "release" ]; then
  EXTRA="--split-per-abi"
fi

flutter build apk --"${MODE}" ${EXTRA} \
  --dart-define=NAVER_MAP_CLIENT_ID="${NAVER_MAP_CLIENT_ID}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define=PETPASS_API_BASE_URL="${PETPASS_API_BASE_URL}"

echo ""
ls -lh build/app/outputs/flutter-apk/*"${MODE}"*.apk
