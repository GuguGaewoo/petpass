# 펫패스 (PetPass)

반려동물 동반여행 사전확인 플랫폼

> 2026 관광데이터 활용 공모전 ②-2 웹·앱 구현 부문 / 지정과제 6번
> 팀 **돌아서지않개**

## 문제

반려동물 동반 조건이 자연어로만 제공되어 모호하다. 실제 수집 데이터의 예:

| 필드 | 값 |
|---|---|
| `acmpyTypeCd` | 전구역 동반가능 |
| `acmpyPsblCpam` | 시각 장애인 안내견 |

앞 필드만 보면 동반 가능처럼 읽히지만, 실제로 입장 가능한 동물은 안내견뿐이다.
일반 반려견은 **불가**다. 조건을 그대로 나열하는 조회형 서비스가 놓치는 지점이며,
현장 입장 거부와 헛걸음의 직접적인 원인이다.

## 해결

TourAPI 의 자연어 조건문을 **구조화 스키마로 정규화**하고, 사용자의 반려동물
프로필(체중·견종)과 **대조 판정**하여 `가능 / 조건부 가능 / 불가 / 정보없음`
4단계로 제시한다. 판정 근거 원문과 데이터 최종수정일을 항상 함께 노출한다.

## 구조

```
pipeline/            Python 배치 — Open API 수집 → 정규화 → Supabase 적재
backend/             FastAPI — 상세 진입 시 Open API 실시간 재확인
app/                 Flutter — 조회 및 판정 UI
db/                  Supabase 스키마 및 RLS 정책
docs/                스키마 정의, 필드 매핑, 데이터 실사 기록
.github/workflows/   일일 동기화, 백엔드 keep-alive
```

### 데이터가 흐르는 두 경로

앱이 관광 Open API 를 직접 호출하지 않는다. 인증키가 빌드 산출물에 들어가고
브라우저 CORS 에도 막히기 때문이다. 대신 두 경로를 쓴다.

```
[앱 시작]
  Flutter → Supabase places (632건 즉시 로드) → 판정

[장소 상세 클릭]
  Flutter → PetPass 백엔드 → detailPetTour2 실시간 호출
          → 정규화(pipeline/normalize.py 재사용) → 판정

[자동 갱신]
  GitHub Actions (매일 04:00 KST) → 변경분만 Open API 재조회
          → 정규화 → Supabase 갱신
```

전체 목록은 정기 동기화된 데이터로 빠르게 검색·판정하고, 사용자가 상세를
확인할 때만 해당 장소를 실시간으로 재검증한다. 상세조회는 같은 장소에 대해
10분(`LIVE_TTL_SECONDS`) 안에는 재호출하지 않아 API 사용량을 억제한다.

배치와 실시간이 **같은 `normalize()` 를 쓴다.** 판정 규칙이 두 벌로 갈라지지
않게 하기 위함이다.

### 장애에 대한 태도

각 단계가 실패해도 그 아래 단계로 조용히 물러난다. 사용자에게는 기능 저하가
보이지 않는다.

| 실패 지점 | 대응 |
|---|---|
| 백엔드·Open API 중단 | 상세화면이 이미 읽어 둔 데이터로 정상 표시 |
| Supabase 중단 | 빌드에 포함된 `assets/places.json` 으로 폴백 |
| 제보 저장소 중단 | 제보 버튼만 감춤, 핵심 기능 무관 |

### 정규화와 판정의 분리

- **정규화** (원문 → 구조화 스키마) — Python. 하루 1회, 무거움
- **판정** (구조화 스키마 + 반려동물 프로필 → 결과) — Dart. 프로필 변경 시마다, 가벼움

`app/lib/domain/` 은 Flutter 를 import 하지 않는 순수 Dart 다. `flutter test` 로
판정 로직 전체를 UI 없이 검증할 수 있다.

## 시작하기

프로젝트 루트에 `.env` 를 만든다. 필요한 값과 설명은 `.env.example` 참고.

```bash
cp .env.example .env      # 값 채우기
```

### db

Supabase SQL Editor 에서 순서대로 실행한다.

```
db/002_places_v3.sql          places 테이블 + kto_api_log
db/003_grant_service_role.sql service_role 권한 (없으면 배치가 42501 로 실패)
```

`db/schema.sql` 은 초기 버전이라 현재 코드와 어긋난다. 다시 실행하지 않는다.

### pipeline

```bash
cd pipeline
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

python seed_supabase.py --dry-run   # 검증만 (DB 미변경)
python seed_supabase.py             # 최초 1회: 에셋 632건 적재
python sync_service.py              # 이후 갱신: 변경분만 Open API 재조회
python -m pytest -q                 # 정규화 회귀 테스트
```

`sync.py` 는 로컬 파일에 이어서 수집하는 초기 스크립트다. CI 에서는
`sync_service.py` 를 쓴다. 진단용 도구는 `tour_probe.py` 참고.

### backend

```bash
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload --port 8000

curl http://localhost:8000/health
```

배포는 `render.yaml` (Blueprint) 참고.

### app

`--dart-define` 으로 키를 주입해야 하므로 스크립트를 쓴다.
`flutter run` 을 직접 호출하면 지도와 실시간 조회가 동작하지 않는다.

```bash
cd app
flutter pub get
./run_web.sh          # 웹 (포트 8080 고정 — 지도 도메인 등록과 일치해야 함)
./build_apk.sh        # APK
flutter analyze
flutter test
```

## 운영

| 항목 | 위치 |
|---|---|
| 일일 데이터 동기화 | `.github/workflows/tourapi-sync.yml` (04:00 KST) |
| 백엔드 keep-alive | `.github/workflows/backend-keepalive.yml` (09~20시 KST) |
| Supabase keep-alive | `.github/workflows/keepalive.yml` (주 1회) |

Actions Secrets: `TOUR_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`,
`SUPABASE_KEY`, `PETPASS_API_BASE_URL`

`SUPABASE_SERVICE_KEY` 는 RLS 를 우회하는 관리자 키다. 앱이나
`--dart-define` 에 절대 넣지 않는다.

## 문서

| 파일 | 내용 |
|---|---|
| `docs/schema.md` | **정규화 스키마 — 단일 진실 출처** |
| `docs/field-mapping.md` | TourAPI 필드 → 스키마 매핑 |
| `docs/data-survey.md` | 데이터 실사 기록 (채움률, 문구 패턴) |
| `docs/기능설명서.md` | 1차 심사 제출용 |

Python 과 Dart 가 같은 스키마를 봐야 하므로 코드로는 공유가 불가능하다.
`docs/schema.md` 를 기준으로 양쪽을 맞춘다. 스키마를 바꿀 때는 이 문서를 먼저 고친다.

## 데이터 출처

한국관광공사 TourAPI (공공데이터포털)

- 반려동물 동반여행 서비스 `KorPetTourService2` — `areaBasedList2`, `detailPetTour2`
- 국문 관광정보 서비스 `KorService2` — `detailCommon2`

공모전 규정상 **서비스 화면 안에서는** 공사를 지칭하는 명칭이나 로고를 쓸 수
없다. 앱과 공개 페이지에는 `공공 관광데이터` 로만 표기한다. 반면 기능설명서에는
활용한 Open API 를 구체적으로 밝혀야 하므로, 개발 문서인 이 README 와
`docs/` 에서는 정확한 명칭을 쓴다.
