# 정규화 스키마

> **이 문서가 단일 진실 출처입니다.**
>
> 정규화는 Python(`pipeline/normalize.py`), 판정은 Dart(`app/lib/domain/`)가
> 담당합니다. 코드로는 타입을 공유할 수 없으므로 이 문서를 기준으로 양쪽을
> 맞춥니다. **스키마를 바꿀 때는 이 문서를 먼저 고치고, 그다음 양쪽 코드를
> 고칩니다.**

현재 버전: `schema_version = 1`
상태: **초안** — `tour_probe.py profile` 결과 반영 후 확정 예정

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

## 판정 규칙 (Dart 측 구현 기준)

입력: `PetProfile { weight_kg, size, is_guide_dog }` + 위 스키마
출력: `가능 / 조건부 가능 / 불가 / 정보없음`

```
if not has_detail                        → 정보없음
if acmpy_type == not_allowed             → 불가
if guide_dog_only and not is_guide_dog   → 불가
if max_weight_kg != null:
    if pet.weight_kg > max_weight_kg     → 불가
if size_restriction != null:
    if pet.size 가 허용 범위 밖           → 불가
if acmpy_type == partial_area            → 조건부 가능
if outdoor_only or extra_fee             → 조건부 가능
if required_items 가 비어있지 않음        → 조건부 가능 (준비물 안내)
otherwise                                → 가능
```

모든 결과에 `source_text` 와 `last_modified` 를 함께 반환한다.

---

## 변경 이력

| 버전 | 날짜 | 내용                                                |
| ---- | ---- | --------------------------------------------------- |
| 1    | 초안 | 실제 필드명 확인 후 최초 작성. profile 결과 반영 전 |
