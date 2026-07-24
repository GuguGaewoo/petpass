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

# 맹견 제외 조건
FIERCE_EXCLUDED = ["맹견 제외", "맹견및", "맹견 및", "맹견제외"]
FIERCE_MENTION = ["맹견"]

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
    """acmpyNeedMtr 파싱 → (준비물 리스트, 자유이용 여부, 기타참조 여부)"""
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
