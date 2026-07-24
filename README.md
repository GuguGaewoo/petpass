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
pipeline/   Python 배치 — TourAPI 수집 → 정규화 → Supabase 적재
app/        Flutter — 조회 및 판정 UI
db/         Supabase 스키마 및 RLS 정책
docs/       스키마 정의, 필드 매핑, 데이터 실사 기록
```

### 왜 배치 구조인가

앱이 TourAPI 를 직접 호출하지 않는다. 배치가 수집·정규화하여 Supabase 에 넣고,
앱은 Supabase 만 조회한다.

- 앱 빌드 산출물에 TourAPI 인증키가 들어가지 않음
- 브라우저 CORS 차단 회피
- API 일일 트래픽 한도 방어
- 수집 시점의 원문·최종수정일이 스냅샷으로 남아 판정 근거가 됨

### 정규화와 판정의 분리

- **정규화** (원문 → 구조화 스키마) — Python. 하루 1회, 무거움
- **판정** (구조화 스키마 + 반려동물 프로필 → 결과) — Dart. 프로필 변경 시마다, 가벼움

`app/lib/domain/` 은 Flutter 를 import 하지 않는 순수 Dart 다. `flutter test` 로
판정 로직 전체를 UI 없이 검증할 수 있다.

## 시작하기

### pipeline

```bash
cd pipeline
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env      # 값 채우기
python sync.py               # 수집 → 정규화 → 적재
```

진단용 도구는 `tour_probe.py` 참고.

### app

```bash
cd app
flutter pub get
flutter run -d chrome
```

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

- 반려동물 동반여행 서비스 `KorPetTourService2`
- 국문 관광정보 서비스 `KorService2`
