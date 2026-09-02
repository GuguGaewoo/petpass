#!/bin/bash
# 웹 실행. 루트 .env 에서 키를 읽어 --dart-define 으로 넘긴다.
#
# 포트를 8080 으로 고정하는 이유:
#   네이버 클라우드에 등록한 Web 서비스 URL 과 일치해야 지도가 뜬다.
#   flutter run 은 기본적으로 매번 임의 포트를 쓴다.
set -e
cd "$(dirname "$0")"

if [ -f ../.env ]; then
  set -a
  . ../.env
  set +a
fi

if [ -z "${NAVER_MAP_CLIENT_ID}" ]; then
  echo "경고: NAVER_MAP_CLIENT_ID 가 비어 있습니다. 지도가 표시되지 않습니다."
  echo "      ~/petpass/.env 를 확인하세요."
fi

exec flutter run -d chrome --web-port=8080 \
  --dart-define=NAVER_MAP_CLIENT_ID="${NAVER_MAP_CLIENT_ID}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define=PETPASS_API_BASE_URL="${PETPASS_API_BASE_URL}"
