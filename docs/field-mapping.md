# TourAPI 필드 → 정규화 스키마 매핑

출처: `KorPetTourService2` / `areaBasedList2`, `detailPetTour2`
(2026-07 `tour_probe.py smoke` 로 실제 응답에서 확인)

## 목록 — areaBasedList2

TourAPI 표준 필드. 장소 기본 정보를 담당한다.

| TourAPI | 스키마 | 비고 |
|---|---|---|
| `contentid` | `content_id` | 기본키. 상세 조회의 조인 키 |
| `title` | `title` | |
| `addr1` + `addr2` | `address` | 합쳐서 저장 |
| `contenttypeid` | `content_type_id` / `content_type` | 12관광지 14문화시설 28레포츠 32숙박 38쇼핑 39음식점 |
| `areacode` | `area_code` | |
| `sigungucode` | `sigungu_code` | |
| `mapy` | `lat` | **위도가 mapy** |
| `mapx` | `lng` | **경도가 mapx** |
| `tel` | `tel` | |
| `firstimage` | `image` | 빈 경우 많음 |
| `modifiedtime` | `last_modified` | **판정 근거의 신선도. 화면 노출 필수** |
| `cat1~3`, `lclsSystm1~3` | 미사용 | 분류체계. 현재 판정에 불필요 |
| `zipcode`, `mlevel`, `createdtime`, `cpyrhtDivCd` | 미사용 | |

## 상세 — detailPetTour2

반려동물 전용 필드. **여기가 판정의 원천이다.**

| TourAPI | 의미 | 스키마 |
|---|---|---|
| `acmpyTypeCd` | 동반 유형 | `acmpy_type` (enum 매핑) |
| `acmpyPsblCpam` | 동반 가능 동물 | `guide_dog_only`, `max_weight_kg`, `size_restriction` (파싱) |
| `acmpyNeedMtr` | 동반 시 필요사항 | `required_items` (파싱) |
| `relaAcdntRiskMtr` | 관련 사고 대비사항 | `risk_notes` (원문) |
| `relaPosesFclty` | 관련 보유 시설 | `facilities` |
| `relaFrnshPrdlst` | 관련 비치 품목 | `provided_items` |
| `relaRntlPrdlst` | 관련 대여 품목 | `rental_items` |
| `relaPurcPrdlst` | 관련 구매 품목 | `purchasable_items` |
| `etcAcmpyInfo` | 기타 동반 정보 | `etc_info` (원문) |

상세 9개 필드 전체가 `source_text` 에 원문 그대로 보존된다.

## API 가 주지 않아 우리가 만들어내는 값

체중 상한과 견종 제한은 **TourAPI 에 숫자 필드로 존재하지 않는다.**
`acmpyPsblCpam` 등의 자연어 안에 묻혀 있어 파싱해야 한다.

| 스키마 필드 | 생성 방식 |
|---|---|
| `max_weight_kg` | "10kg 이하" 패턴 정규식 |
| `size_restriction` | 소형견/중형견/대형견 키워드 |
| `guide_dog_only` | 안내견/보조견/시각장애인 키워드 |
| `required_items` | 목줄/이동장/입마개 등 키워드 매칭 |
| `confidence` | 위 항목들의 추출 성공 비율 |

이 변환이 서비스의 차별점이며, 기능설명서 **#조건_해석** 항목이 가리키는 작업이다.
규칙은 `pipeline/rules/patterns.py` 에 모여 있다.

## 확인 필요

- [ ] `acmpyTypeCd` 의 고유값 전체 (profile 결과로 `ACMPY_TYPE_MAP` 완성)
- [ ] `acmpyPsblCpam` 표현이 몇 가지로 수렴하는지 (규칙 기반 vs LLM 정규화 판단)
- [ ] 국문 `contentid` 가 `EngService2` 에서도 통하는지 (영문 확장 시)
