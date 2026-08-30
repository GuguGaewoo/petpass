#!/usr/bin/env bash
# Vercel 빌드 스크립트.
#
# Vercel 빌드 환경에는 Flutter 가 없다. 매 배포마다 SDK 를 내려받아
# 웹을 빌드한다. 로컬 개발과 무관하며 Vercel 에서만 실행된다.
#
# 키는 Vercel 대시보드의 Environment Variables 에서 읽는다.
# .env 파일은 저장소에 없으므로(커밋 금지) 여기서 쓸 수 없다.
#
#   Settings → Environment Variables 에 아래 4개를 등록해야 한다:
#     NAVER_MAP_CLIENT_ID
#     SUPABASE_URL
#     SUPABASE_PUBLISHABLE_KEY
#     PETPASS_API_BASE_URL
#
#   SUPABASE_SERVICE_KEY 와 TOUR_API_KEY 는 절대 등록하지 않는다.
#   --dart-define 으로 넘긴 값은 빌드 산출물에 그대로 박힌다.

set -euo pipefail

# 로컬과 같은 버전을 쓴다. stable 을 그대로 따라가면 어느 날 Flutter 가
# 올라가면서 빌드가 깨질 수 있다. 올릴 때는 로컬에서 먼저 확인하고 여기도 같이 바꾼다.
FLUTTER_VERSION="3.47.2"
FLUTTER_DIR="$HOME/flutter"

echo "── Flutter ${FLUTTER_VERSION} 준비 ──"

if [ -d "${FLUTTER_DIR}/bin" ]; then
  echo "  캐시된 SDK 사용"
else
  # --depth 1 로 이력 없이 받는다. 전체 clone 은 1GB 가 넘는다.
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

# Vercel 빌드 컨테이너는 매번 새로 만들어지므로 소유자 검사에 걸린다.
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter --version

echo ""
echo "── 환경변수 확인 ──"

# 값이 비면 지도·제보·실시간 조회가 조용히 죽은 채로 배포된다.
# 배포된 뒤에 발견하는 것보다 여기서 멈추는 편이 낫다.
missing=0
for key in NAVER_MAP_CLIENT_ID SUPABASE_URL SUPABASE_PUBLISHABLE_KEY PETPASS_API_BASE_URL; do
  if [ -z "${!key:-}" ]; then
    echo "  ✗ ${key} 없음"
    missing=1
  else
    echo "  ✓ ${key}"
  fi
done

if [ "${missing}" -ne 0 ]; then
  echo ""
  echo "Vercel → Settings → Environment Variables 에 위 값을 등록하세요."
  exit 1
fi

# 서버 전용 키가 실수로 등록되면 빌드에 섞일 수 있으므로 막는다.
for forbidden in SUPABASE_SERVICE_KEY TOUR_API_KEY; do
  if [ -n "${!forbidden:-}" ]; then
    echo ""
    echo "✗ ${forbidden} 가 빌드 환경에 있습니다."
    echo "  이 키는 앱에 들어가면 안 됩니다. Vercel 환경변수에서 제거하세요."
    exit 1
  fi
done

echo ""
echo "── 웹 빌드 ──"
cd app
flutter pub get

flutter build web --release \
  --dart-define=NAVER_MAP_CLIENT_ID="${NAVER_MAP_CLIENT_ID}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define=PETPASS_API_BASE_URL="${PETPASS_API_BASE_URL}"

echo ""
echo "완료: app/build/web"
ls -la build/web | head
