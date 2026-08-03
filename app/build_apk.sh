#!/bin/bash
# APK 빌드. 루트 .env 에서 키를 읽어 --dart-define 으로 넘긴다.
#
# --dart-define 값은 빌드 시점에 코드로 컴파일된다.
# 그냥 flutter build apk 를 돌리면 키가 빈 문자열이 되어
# 앱에서 "지도 키가 설정되지 않았습니다" 가 뜬다.
#
# 사용:
#   ./build_apk.sh           디버그 (실기기 확인용)
#   ./build_apk.sh release   릴리스 (스토어 제출용, 서명키 필요)
set -e
cd "$(dirname "$0")"

if [ -f ../.env ]; then
  set -a
  . ../.env
  set +a
fi

if [ -z "${NAVER_MAP_CLIENT_ID}" ]; then
  echo "경고: NAVER_MAP_CLIENT_ID 가 비어 있습니다. 지도가 표시되지 않습니다."
fi

MODE="${1:-debug}"
flutter build apk --"${MODE}" \
  --dart-define=NAVER_MAP_CLIENT_ID="${NAVER_MAP_CLIENT_ID}"

echo ""
echo "생성됨: build/app/outputs/flutter-apk/app-${MODE}.apk"
