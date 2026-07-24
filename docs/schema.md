# 정규화 스키마

> **이 문서가 단일 진실 출처입니다.**
>
> 정규화는 Python(`pipeline/normalize.py`), 판정은 Dart(`app/lib/domain/`)가
> 담당합니다. 코드로는 타입을 공유할 수 없으므로 이 문서를 기준으로 양쪽을
> 맞춥니다. **스키마를 바꿀 때는 이 문서를 먼저 고치고, 그다음 양쪽 코드를
> 고칩니다.**

현재 버전: `schema_version = 2`
상태: **확정** — 전국 632건 실사 반영 (2026-07)

---

## 설계 원칙

1. **언어 독립적으로 저장한다.** 수치·불리언·enum 으로 저장하면 다국어 확장 시
   번역이 필요 없다. 자연어가 남는 곳은 `source_text` 하나뿐이다.
2. **원문을 절대 버리지 않는다.** 판정 결과에는 항상 근거 원문과 데이터
   최종수정일을 함께 노출한다. 신뢰성 확보이자 책임소재 근거다.
3. **모르는 것은 모른다고 한다.** 파싱 실패를 임의로 추정하지 않고 `null` 로
   두고 판정에서 `정보없음` 으로 처리한다.

---

## 필드 정의

### 장소 기본 정보

| 필드              | 타입   | 설명                                         |
| ----------------- | ------ | -------------------------------------------- |
| `content_id`      | string | TourAPI contentid. 기본키                    |
| `title`           | string | 장소명                                       |
| `address`         | string | addr1 + addr2                                |
| `content_type`    | string | 관광지/문화시설/레포츠/숙박/쇼핑/음식점/기타 |
| `content_type_id` | string | TourAPI contenttypeid 원값                   |
| `area_code`       | string | 시도 코드                                    |
| `sigungu_code`    | string | 시군구 코드                                  |
| `lat` / `lng`     | float? | 위도(mapy) / 경도(mapx)                      |
| `tel`             | string | 전화번호                                     |
| `image`           | string | 대표 이미지 URL                              |

### 구조화된 제약 조건

| 필드                | 타입     | 값                                                             | 설명                               |
| ------------------- | -------- | -------------------------------------------------------------- | ---------------------------------- |
| `has_detail`        | bool     |                                                                | 상세 조건 데이터가 하나라도 있는가 |
| `acmpy_type`        | string?  | `all_area` `partial_area` `not_allowed` `unknown_value` `null` | 동반 유형. **판정 1차 기준**       |
| `guide_dog_only`    | bool     |                                                                | **판정 2차 기준. 아래 주의 참고**  |
| `max_weight_kg`     | float?   |                                                                | 체중 상한. "10kg 이하" 형태만 인정 |
| `size_restriction`  | string?  | `small` `medium` `large` `null`                                | 견종 크기 제한                     |
| `breed_restricted`  | bool     |                                                                | 맹견 등 견종 제한 문구 존재        |
| `required_items`    | string[] |                                                                | 준비물 체크리스트                  |
| `provided_items`    | string[] |                                                                | 비치 품목 (준비물에서 차감 가능)   |
| `rental_items`      | string[] |                                                                | 대여 품목                          |
| `purchasable_items` | string[] |                                                                | 구매 가능 품목                     |
| `facilities`        | string[] |                                                                | 보유 시설                          |
| `extra_fee`         | bool     |                                                                | 추가 요금 언급                     |
| `outdoor_only`      | bool     |                                                                | 야외/테라스 한정                   |
| `risk_notes`        | string   |                                                                | 사고 대비사항 원문                 |
| `etc_info`          | string   |                                                                | 기타 동반 정보 원문                |

### 근거 및 추적

| 필드            | 타입     | 설명                                                 |
| --------------- | -------- | ---------------------------------------------------- |
| `source_text`   | object   | 상세 필드 9종의 원문 전체. **판정 화면에 노출 필수** |
| `last_modified` | ISO8601? | TourAPI modifiedtime. **판정 화면에 노출 필수**      |
| `collected_at`  | ISO8601  | 배치 수집 시각                                       |
| `confidence`    | float    | 0.0~1.0. 구조화 성공 신호 비율                       |

---

## ⚠ guide_dog_only — 이 서비스의 핵심

실제 수집된 레코드:

```
acmpyTypeCd   : "전구역 동반가능"
acmpyPsblCpam : "시각 장애인 안내견"
```

`acmpyTypeCd` 만 보면 동반 가능처럼 읽히지만, 실제 입장 가능한 동물은
안내견뿐이므로 **일반 반려견은 불가**다.

따라서 판정은 두 필드를 **반드시 교차 검증**해야 한다.
`acmpy_type` 단독으로 판정하면 오답이 나온다.

이 케이스는 `pipeline/tests/test_normalize.py::test_guide_dog_trap` 으로
회귀 테스트가 걸려 있다. **절대 깨뜨리지 말 것.**

---

## 판정 규칙 v2

구현: `app/lib/domain/verdict_engine.dart` (순수 Dart, 테스트 22건)
검증: `pipeline/verdict_preview.py` 로 632건 전체 분포 확인

뱃지가 답하는 질문은 하나다: **"데려가면 들어갈 수 있나?"**

| 등급        | 의미                             |
| ----------- | -------------------------------- |
| 불가        | 데려가면 거부당함                |
| 조건부 가능 | 준비물이 없으면 거부당할 수 있음 |
| 가능        | 그냥 가면 됨                     |
| 정보없음    | 판단 근거 부족                   |

```
if not has_detail                          → 정보없음

# 법률 우선: 장애인복지법상 보조견 출입 거부는 금지
if pet.is_guide_dog                        → 가능 (이하 제약 전부 건너뜀)

if explicitly_denied                       → 불가
if guide_dog_only                          → 불가   ← 핵심 교차검증
if needs_inquiry                           → 정보없음

if max_weight_kg and pet.weight > 상한      → 불가
if size_limit and pet.size > 상한           → 불가
if fierce_excluded and pet.is_fierce       → 불가

extra = required_items - BASELINE_ITEMS
if extra                                   → 조건부 가능
if weight_in_etc_only or see_etc_info      → 조건부 가능
if acmpy_type is null or unknown_value     → 정보없음

if acmpy_type == partial_area              → 가능 (사유: 이용 구역 제한)
otherwise                                  → 가능
```

`BASELINE_ITEMS = {목줄}` — 동물보호법상 외출 시 안전조치는 이미 의무이며
장소 고유의 제약이 아니다. 실측 632건 중 414건(65.5%)이 목줄만 요구하므로,
이를 조건으로 세면 대부분이 '조건부 가능'이 되어 뱃지가 변별력을 잃는다.
입마개는 맹견 한정 의무이므로 제외하지 않는다.

**일부구역은 등급을 낮추지 않는다.** 입장 거부가 아니라 이용 범위 제한이다.
대신 `구역 제한` 칩과 `zoneNote`(etcAcmpyInfo 원문)로 전달한다.

### 칩 — 등급과 별개로 카드에 표시

`구역 제한` `N kg 이하` `소형견까지` `맹견 제외` `최대 N마리`
`N kg↑ 입마개` `추가 요금` `야외만`

### 실측 분포 (632건)

| 프로필            | 가능  | 조건부 | 불가  | 정보없음 |
| ----------------- | ----- | ------ | ----- | -------- |
| 말티즈 4kg        | 68.2% | 23.9%  | 4.4%  | 3.5%     |
| 코커스패니얼 12kg | 61.7% | 19.1%  | 16.1% | 3.0%     |
| 리트리버 30kg     | 61.1% | 16.9%  | 19.1% | 2.8%     |

불가가 프로필에 따라 28건 ↔ 121건으로 4.3배 벌어진다. 대조 판정이
실제로 결과를 가르고 있다는 근거다.

모든 결과에 `source_text` 와 `last_modified` 를 함께 반환한다.

---

## 변경 이력

| 버전 | 날짜    | 내용                                                   |
| ---- | ------- | ------------------------------------------------------ |
| 1    | 초안    | 실제 필드명 확인 후 최초 작성                          |
| 2    | 2026-07 | 전국 632건 실사 반영. 파싱 규칙 확정, 판정 규칙 재정의 |

### v1 → v2 주요 변경

- `acmpy_type` 에서 `not_allowed` 제거 — API 에 해당 값이 존재하지 않음
- 목줄을 `BASELINE_ITEMS` 로 분리하여 등급 산정에서 제외
- 일부구역을 조건부에서 가능으로 이동, 칩으로 표시
- 체중 출처를 `acmpyPsblCpam` 으로 한정, `weight_in_etc_only` 플래그 신설
- `muzzle_over_kg` 신설 — 'N kg 이상 입마개'를 체중 상한으로 오인하던 문제
- 보조견 법률 예외를 판정 최상단에 배치
