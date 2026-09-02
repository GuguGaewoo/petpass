#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
자연어 조건문 파싱 규칙.

전국 632건 실사(docs/data-survey.md) 결과를 반영한 확정 버전.

핵심 설계:
  - acmpyPsblCpam 은 142가지 표현이지만 '조합형'이다. 문자열 전체를 매칭하지
    않고 독립 신호(견종/체중/맹견/안내견/이동장/접종)를 각각 추출한다.
  - acmpyNeedMtr 는 고정 어휘 7개의 쉼표 나열이다. 완전 구조화 가능.
  - etcAcmpyInfo 의 체중 언급은 구역별 예외가 섞여 있어 확정값으로 쓰지 않는다.
  - etcAcmpyInfo 는 조건과 요구가 한 문장에 섞인 자연어다.
    "맹견의 경우, 입마개 착용 필수" 처럼 조건절을 분리해야 한다.

※ 이 파일의 정규식은 반드시 '단일 필드'에 적용할 것.
  source_text 전체를 이어붙인 문자열에 쓰면 필드 경계를 넘어 오탐된다.
  예) acmpyPsblCpam 의 "맹견 제외" + acmpyNeedMtr 의 "입마개 착용"
      -> "맹견 ... 입마개" 로 잘못 매칭됨
"""

import re

# ══════════════════════════════════════════════════
# 동반 유형 (acmpyTypeCd) — 실측 결과 2값 + 빈값뿐
# ══════════════════════════════════════════════════
ACMPY_TYPE_MAP = {
    "전구역 동반가능": "all_area",        # 291건 46.0%
    "일부구역 동반가능": "partial_area",  # 300건 47.5%
}
# ※ "동반불가" 값은 존재하지 않는다. 이 API 는 동반 가능한 곳만 수록한다.
#    따라서 '불가' 판정은 acmpyPsblCpam 의 제약에서만 나온다.

# ══════════════════════════════════════════════════
# 동반 시 필요사항 (acmpyNeedMtr) — 고정 어휘의 쉼표 나열
# ══════════════════════════════════════════════════
NEED_ITEM_MAP = {
    "목줄 착용": "목줄",
    "입마개 착용": "입마개",
    "이동장(켄넬)사용": "이동장",
    "이동장(켄넬) 사용": "이동장",
    "반려동물 유모차 탑승": "유모차",
    "매너벨트 착용": "매너벨트",
}
NEED_FREE = "자유이용"   # 준비물 아님 — 제약 없음
NEED_ETC = "기타"        # 준비물 아님 — etcAcmpyInfo 확인 신호

# ══════════════════════════════════════════════════
# 안내견 전용 — acmpyTypeCd 가 '가능'이어도 일반 반려견은 불가
# ══════════════════════════════════════════════════
GUIDE_DOG_ONLY = [
    "안내견", "맹인 안내견", "시각 장애인", "시각장애인",
    "장애인 보조견", "보조견",
]

# 위 목록은 acmpyPsblCpam(가능동물) 전용이다. 그 필드는 "안내견" 한 단어만
# 들어 있는 경우가 많아 단순 포함 검사로 충분하다.
#
# etcAcmpyInfo(기타정보)는 문장이라 같은 방식을 쓸 수 없다. 안내견이
# 언급되는 맥락이 정반대로 갈리기 때문이다.
#
#   전용   "장애우 안내견만 이용가능"          → 일반견 불가
#   예외   "안내견 제외 이동장으로만 동반 가능" → 일반견도 가능(이동장 필요)
#
# 후자를 전용으로 잡으면 갈 수 있는 곳이 불가로 뒤집힌다. 그래서
# '~만 가능' 형태일 때만 전용으로 본다.
GUIDE_DOG_ONLY_IN_ETC_RE = re.compile(
    r"(?:안내견|보조견)[^.\n]{0,6}?만\s*(?:이용|출입|입장|동반)?\s*가능"
    r"|(?:안내견|보조견)\s*(?:이외|외)[^.\n]{0,10}?(?:출입|동반|입장)\s*(?:금지|불가)"
)

# 다만 '전시실 내에는 안내견 이외 동반 금지' 처럼 특정 구역만 한정하는
# 문장이 있다. 이때 장소 전체를 안내견 전용으로 보면, 야외는 갈 수 있는
# 곳이 통째로 불가가 된다. 구역을 가리키는 말이 앞에 오면 제외한다.
# (그 구역 제한은 banned_zones 가 따로 담는다)
_GUIDE_DOG_ZONE_SCOPED = re.compile(
    r"(?:실내|내부|안쪽|관내|전시실|전시장|전시관|박물관|식당|카페|매장"
    r"|객실|숙소|수영장|체육)[^.\n]{0,12}?(?:안내견|보조견)"
)

# ══════════════════════════════════════════════════
# 체중
# ══════════════════════════════════════════════════
_KG = r"(?:kg|KG|Kg|kG|㎏|킬로|키로)"

# "10kg 이하", "8KG 미만", "15kg미만", "10kg 까지"
WEIGHT_MAX_RE = re.compile(rf"(\d+(?:\.\d+)?)\s*{_KG}\s*(?:이하|미만|까지|이내)")

# "15Kg이상 동반 불가" — 이상 + 불가 = 사실상 상한
WEIGHT_OVER_BAN_RE = re.compile(
    rf"(\d+(?:\.\d+)?)\s*{_KG}\s*이상[^.\n]{{0,25}}?(?:불가|금지|제한|안\s*됨)"
)

# "대형견(25kg 이상), 입마개 착용 필수" — 상한이 아니라 입마개 임계값
WEIGHT_MUZZLE_RE = re.compile(
    rf"(\d+(?:\.\d+)?)\s*{_KG}\s*이상[^.\n]{{0,25}}?입마개"
)

# "최대 2마리까지", "소형견 1마리"
COUNT_RE = re.compile(r"(\d+)\s*마리")

# ══════════════════════════════════════════════════
# 견종 크기
# ══════════════════════════════════════════════════
SIZE_MAP = {
    "small": ["소형견", "소형 반려견", "소형"],
    "medium": ["중형견", "중형"],
    "large": ["대형견", "대형"],
}
# "중/소형견"이 small 로만 잡히지 않도록 먼저 검사
MID_SMALL = ["중/소형견", "중소형견", "중, 소형견", "중,소형견", "중소형"]

# 전 견종 허용 ("전 견동"은 실제 데이터에 존재하는 오타)
ALL_BREED = ["전 견종", "전견종", "전 견동", "전견동", "모든 견종"]

# ══════════════════════════════════════════════════
# 맹견
# ══════════════════════════════════════════════════
# 배제 조항.
#
# 이전에는 ["맹견 제외", "맹견및", "맹견 및", "맹견제외"] 문자열 목록이었으나,
# "맹견 및" 하나만으로는 배제인지 요구인지 구분할 수 없어 오판정이 났다.
#   "맹견 및 대형견의 경우, 입마개 착용 필수"  -> 요구 (입마개 쓰면 가능)
#   "전 견종 동반가능(맹견 제외)"              -> 배제 (맹견 불가)
# 실측 2건이 앞 문장인데 '맹견 불가'로 뒤집혔다. 배제 어휘를 함께 요구한다.
FIERCE_EXCLUDED_RE = re.compile(r"맹견[^.\n]{0,15}?(?:제외|불가|금지|불허|안\s*됨)")
FIERCE_MENTION = ["맹견"]

# 조건부 입마개.
# "- 맹견의 경우, 입마개 착용 필수" 형태. 실측 283건이 규칙 부재로 유실됐다.
# 조건(맹견)과 요구(입마개)가 한 문장에 붙어 있어, 구조화하지 않으면
# "누구에게 필요한가"를 판단할 수 없다.
# acmpyNeedMtr 의 "입마개 착용"(무조건 요구, 40건)과는 별개다.
MUZZLE_IF_FIERCE_RE = re.compile(r"맹견[^.\n]{0,25}?입마개")

# "맹견 및 대형견의 경우, 입마개 착용 필수" — 대형견도 대상 (실측 2건)
MUZZLE_IF_LARGE_RE = re.compile(r"맹견[^.\n]{0,10}대형견[^.\n]{0,20}?입마개")
LARGE_DOG_KG = 25.0   # DogSize.fromWeight 의 대형견 경계와 맞춘다

# ══════════════════════════════════════════════════
# 기타 신호
# ══════════════════════════════════════════════════
NOT_ALLOWED = ["불가", "동반 불가", "동반불가"]
ASK_PHONE = ["전화문의", "전화 문의", "문의 요망", "사전 문의"]
KENNEL_IN_CPAM = ["이동장", "켄넬", "캐리어"]
VACCINE = ["예방접종", "접종 완료", "광견병"]
EXTRA_FEE = ["추가요금", "추가 요금", "별도 요금", "추가 비용", "유료"]
OUTDOOR_ONLY = ["야외만", "테라스만", "실외만", "야외 한정", "테라스 한정",
                "야외에서만", "테라스에서만"]

# 위 문자열 목록으로는 "실내는 동반 불가", "실내반입 불가, 마당에서 방목가능"
# 같은 우회 표현을 놓친다. 실측 24건이 여기서 유실됐다.
#
# 식당에서 특히 중요하다. 실내를 기대하고 갔다가 겨울에 테라스로 안내받으면
# 사실상 헛걸음이다. "구역 제한" 만으로는 어느 구역인지 알 수 없다.
OUTDOOR_ONLY_RE = re.compile(
    r"실내[^.\n]{0,15}?(?:동반\s*)?(?:불가|어렵|안\s*됩|안\s*돼|제한|금지)"
    r"|야외\s*(?:테라스|공간)[^.\n]{0,10}?(?:만|가능|이용)"
    r"|테라스[^.\n]{0,10}?(?:에서만|만\s*가능|이용은?\s*가능)"
    r"|마당에서[^.\n]{0,10}?(?:만|가능)"
)

# ══════════════════════════════════════════════════
# 배변봉투 — 실측 358건 언급, 기존 규칙 없어 전량 유실
# ══════════════════════════════════════════════════
# 동물보호법상 배설물 수거는 장소와 무관한 소유자 의무다.
# 목줄과 같은 범주이므로 판정 엔진에서 baseline 으로 다룬다.
# required_items 로 세면 358곳이 일제히 '조건부 가능'이 되어 뱃지가 변별력을 잃는다.
POOP_BAG_RE = re.compile(r"배변\s*(?:봉투|봉지)")

# "종합안내소에서 배변봉투 무료지급" — 현장 비치로 분류
POOP_BAG_PROVIDED_RE = re.compile(
    r"배변\s*(?:봉투|봉지)[^.\n]{0,30}?(?:무료|지급|제공|비치|구비)"
)


# ══════════════════════════════════════════════════
# 동반 불가 구역 — 실측 75개 문장
# ══════════════════════════════════════════════════
# "동반 가능" 뱃지만 보고 갔다가 실내에서 막히는 것이 이 서비스가 막으려는
# 헛걸음의 전형이다. 원문에는 어느 구역이 안 되는지 적혀 있지만 지금까지
# 구조화되지 않아 판정에 쓰이지 못했다.
#
# 구역명 자체는 "청운답원", "스페이스 워크"처럼 그 장소에만 있는 고유명사가
# 많아 일반화가 안 된다. 대신 반복해서 나타나는 구역 '유형'만 분류한다.
# 실측 75건 중 45건이 유형 분류되고 오분류는 0건이었다.

ZONE_BAN_RE = re.compile(
    r"(?:동반|출입|입장|이용)\s*(?:불가|금지)|출입불가|동반불가"
)

# 금지 표현 앞이 구역이 아니라 '조건'인 경우.
#   "필수예방접종 미완료 시 동반 불가"  → 구역 아님
#   "반려동물의 몸이 외부에 노출되면"    → 상태 조건
_ZONE_CONDITION_TAIL = re.compile(r"(?:시|시에|면|므로|경우|때|중|이유로|이외|단독)$")

# 금지 표현 앞이 구역이 아니라 '대상'인 경우.
#   "맹견 동반 불가", "5대맹견 및 하이브리드 반려견 동반 불가"
# 이들은 fierce_excluded 등 별도 규칙이 이미 처리한다.
_ZONE_SUBJECT = re.compile(
    r"맹견|반려견|반려동물|보호자|하이브리드|소형견|중형견|대형견"
)

# 나열 구분자. "식당, 카페, 일부매장" / "철도박물관 및 카페" / "마트와 식당"
_ZONE_SPLIT = re.compile(r"[,，]|\s+및\s+|\s*와\s+|\s*과\s+")

# 구역 유형 사전. 앞에 오는 항목이 우선한다(실내가 가장 포괄적).
ZONE_KINDS = {
    "실내": ["실내", "내부", "안쪽", "관내"],
    "식음료": ["식당", "카페", "식음료", "음식", "매장", "마트", "편의점", "레스토랑"],
    "전시": ["전시", "박물관", "미술관", "기념관", "체험관", "문화센터", "문화관", "과학관"],
    "숙박": ["숙소", "객실", "휴양관", "카라반", "방갈로", "선실", "호텔", "펜션"],
    "체육": ["수영장", "체육", "놀이", "운동장", "캠핑장", "족욕"],
    "자연": ["잔디", "국립공원", "해수욕장", "산책로", "정원", "농장", "공원"],
    "탈것": ["전기차량", "유람선", "케이블카", "모노레일", "열차"],
}

# 조사. "실내는" → "실내"
_ZONE_PARTICLE = re.compile(r"(?:은|는|이|가|을|를|도)$")

# 이보다 긴 앞부분은 구역명이 아니라 문장 전체가 붙은 것으로 본다.
_ZONE_HEAD_MAX = 40


# ══════════════════════════════════════════════════
# 추출 함수
# ══════════════════════════════════════════════════
def find_any(text, patterns):
    return any(p in text for p in patterns)


def extract_max_weight(text):
    """상한 체중(kg). '이상+불가'도 상한으로 인정. 입마개 임계값은 제외."""
    if not text:
        return None
    m = WEIGHT_MAX_RE.search(text)
    if m:
        return float(m.group(1))
    m = WEIGHT_OVER_BAN_RE.search(text)
    if m:
        return float(m.group(1))
    return None


def extract_muzzle_threshold(text):
    """'N kg 이상 입마개 필수'의 N. 상한이 아니라 조건부 임계값."""
    if not text:
        return None
    m = WEIGHT_MUZZLE_RE.search(text)
    return float(m.group(1)) if m else None


def extract_max_count(text):
    """동반 가능 마리수 상한"""
    if not text:
        return None
    m = COUNT_RE.search(text)
    return int(m.group(1)) if m else None


def extract_size(text):
    """허용되는 최대 견종 크기. '중/소형견' 복합 표현을 우선 처리."""
    if not text:
        return None
    if find_any(text, MID_SMALL):
        return "medium"
    for size in ("large", "medium", "small"):   # 관대한 쪽 우선
        if find_any(text, SIZE_MAP[size]):
            return size
    return None


def extract_need_items(text):
    """acmpyNeedMtr 파싱 -> (준비물 리스트, 자유이용 여부, 기타참조 여부)"""
    if not text or not text.strip():
        return [], False, False
    tokens = [t.strip() for t in text.split(",") if t.strip()]
    items, free, etc = [], False, False
    for t in tokens:
        if t == NEED_FREE:
            free = True
        elif t == NEED_ETC:
            etc = True
        else:
            name = NEED_ITEM_MAP.get(t)
            if name:
                if name not in items:
                    items.append(name)
            else:
                if t not in items:      # 매핑에 없는 새 어휘는 원문 보존
                    items.append(t)
    return items, free, etc


def split_items(text):
    """쉼표·슬래시로 나열된 품목 문자열을 리스트로"""
    if not text or not text.strip():
        return []
    parts = re.split(r"[,/·\n]|\s{2,}", text)
    return [p.strip() for p in parts if p.strip()]


def extract_fierce_excluded(text):
    """맹견 배제 조항 여부.

    '맹견 및 대형견의 경우 입마개'(요구)를 배제로 오판하지 않도록
    배제 어휘가 함께 있을 때만 True 를 반환한다.
    """
    return bool(text) and bool(FIERCE_EXCLUDED_RE.search(text))


def extract_muzzle_if_fierce(text):
    """'맹견의 경우 입마개' — 견종 조건부 요구. 체중 조건과 별개다.

    배제 조항이 있는 곳은 애초에 맹견이 못 들어가므로 요구로 보지 않는다.
    """
    if not text or FIERCE_EXCLUDED_RE.search(text):
        return False
    return bool(MUZZLE_IF_FIERCE_RE.search(text))


def extract_muzzle_large_threshold(text):
    """'맹견 및 대형견의 경우 입마개' -> 대형견 경계를 임계값으로 삼는다."""
    if not text:
        return None
    return LARGE_DOG_KG if MUZZLE_IF_LARGE_RE.search(text) else None


def extract_poop_bag(text):
    """배변봉투 -> (요구됨, 현장비치됨)"""
    if not text:
        return False, False
    if POOP_BAG_PROVIDED_RE.search(text):
        return True, True
    return bool(POOP_BAG_RE.search(text)), False


def extract_outdoor_only(text):
    """야외(테라스·마당)에서만 동반 가능한가.

    실내 동반이 막혀 있다는 표현을 포함한다. 어느 구역인지 모르는
    "구역 제한" 과 달리, 사용자가 무엇을 기대해야 하는지 알려준다.
    """
    if not text:
        return False
    return find_any(text, OUTDOOR_ONLY) or bool(OUTDOOR_ONLY_RE.search(text))


def _zone_kind(zone):
    """구역명 하나를 유형으로 분류한다. 해당 없으면 None."""
    for kind, keywords in ZONE_KINDS.items():
        if any(k in zone for k in keywords):
            return kind
    return None


def extract_banned_zones(text):
    """동반 불가 구역의 '유형' 목록을 뽑는다.

    반환 예: ["실내", "식음료"]

    구역명 자체(청운답원 등)는 그 장소에만 있는 고유명사가 많아
    일반화할 수 없으므로 유형만 남긴다. 유형을 알 수 없는 구역은
    조용히 건너뛴다. 화면에는 원문이 함께 표시되므로 정보가
    사라지지는 않는다.

    잘못 뽑는 것이 못 뽑는 것보다 나쁘다. "동반 가능한데 실내는 불가"를
    잘못 표시하면 사용자가 갈 수 있는 곳을 포기하게 된다.
    """
    if not text:
        return []

    kinds = []
    for line in text.split("\n"):
        line = line.strip().lstrip("-").strip()
        if not line:
            continue

        m = ZONE_BAN_RE.search(line)
        if not m:
            continue

        head = _ZONE_PARTICLE.sub("", line[: m.start()].strip()).strip()

        # 구역명이 아닌 경우를 걸러낸다.
        if not head or len(head) > _ZONE_HEAD_MAX:
            continue
        if _ZONE_CONDITION_TAIL.search(head):
            continue
        if _ZONE_SUBJECT.search(head):
            continue

        for zone in _ZONE_SPLIT.split(head):
            kind = _zone_kind(zone.strip())
            if kind and kind not in kinds:
                kinds.append(kind)

    return kinds


def extract_guide_dog_only(cpam, etc):
    """안내견(보조견)만 동반 가능한가.

    가능동물 문구는 단어 포함으로, 기타정보는 '~만 가능' 형태일 때만
    본다. 기타정보에서 단순 포함으로 잡으면 "안내견 제외 이동장으로만
    동반 가능"(일반견도 가능)이 불가로 뒤집힌다.
    """
    if find_any(cpam, GUIDE_DOG_ONLY):
        return True
    if not etc:
        return False
    for line in etc.split("\n"):
        if not GUIDE_DOG_ONLY_IN_ETC_RE.search(line):
            continue
        # 특정 구역만 한정한 문장이면 장소 전체 전용이 아니다.
        if _GUIDE_DOG_ZONE_SCOPED.search(line):
            continue
        return True
    return False
