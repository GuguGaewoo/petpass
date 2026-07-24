#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
자연어 조건문 파싱 규칙.

⚠ 이 파일은 `python tour_probe.py profile` 결과를 보고 계속 채워야 합니다.
   지금 값은 초기 샘플 기준 추정이며, 실제 문구 분포를 확인한 뒤 확정하세요.
   규칙을 추가할 때는 반드시 tests/test_normalize.py 에 케이스도 같이 추가할 것.
"""

import re

# ── 동반 유형 (acmpyTypeCd) ────────────────────────
# profile 의 "acmpyTypeCd 고유값" 출력을 보고 여기를 완성하세요.
ACMPY_TYPE_MAP = {
    "전구역 동반가능": "all_area",
    "일부구역 동반가능": "partial_area",
    "동반불가": "not_allowed",
    # TODO: profile 결과의 나머지 고유값 추가
}

# ── 안내견 전용 신호 ──────────────────────────────
# acmpyTypeCd 가 "동반가능" 이어도 이 표현이 있으면 일반 반려견은 불가.
# 서비스의 핵심 판정 케이스이므로 누락되면 안 됨.
GUIDE_DOG_ONLY = [
    "안내견", "장애인 보조견", "보조견", "시각 장애인", "시각장애인",
]

# ── 체중 ──────────────────────────────────────────
WEIGHT_RE = re.compile(r"(\d+(?:\.\d+)?)\s*(?:kg|KG|Kg|㎏|킬로|키로)")
# "10kg 이하", "10kg 미만" 처럼 상한을 뜻하는 표현
WEIGHT_MAX_RE = re.compile(
    r"(\d+(?:\.\d+)?)\s*(?:kg|KG|Kg|㎏|킬로|키로)\s*(?:이하|미만|까지|이내)"
)

# ── 견종 크기 ─────────────────────────────────────
SIZE_MAP = {
    "small": ["소형견", "소형 반려견", "소형"],
    "medium": ["중형견", "중형"],
    "large": ["대형견", "대형"],
}

# ── 맹견 / 견종 제한 ──────────────────────────────
BREED_RESTRICTED = ["맹견", "사나운", "공격성"]

# ── 준비물 (acmpyNeedMtr 등에서 추출) ──────────────
# key = 체크리스트에 표시할 이름, value = 이 표현이 나오면 필요한 것으로 판단
REQUIRED_ITEMS = {
    "목줄": ["목줄", "리드줄", "리드 줄", "하네스"],
    "이동장": ["케이지", "이동장", "켄넬", "캐리어", "이동 가방"],
    "입마개": ["입마개"],
    "배변봉투": ["배변봉투", "배변 봉투", "배변패드", "배변 패드", "위생봉투"],
    "예방접종 증명": ["예방접종", "접종 증명", "광견병"],
    "인식표": ["인식표", "등록증", "동물등록"],
    "매너벨트": ["매너벨트", "매너 벨트"],
}

# ── 추가 요금 ─────────────────────────────────────
EXTRA_FEE = ["추가요금", "추가 요금", "별도 요금", "추가 비용", "유료"]

# ── 구역 제한 ─────────────────────────────────────
INDOOR_HINT = ["실내", "매장 내", "객실", "내부"]
OUTDOOR_ONLY = ["야외만", "테라스만", "실외만", "야외 한정", "테라스 한정"]


# ── 추출 함수 ─────────────────────────────────────
def find_any(text, patterns):
    """patterns 중 하나라도 text 에 있으면 True"""
    return any(p in text for p in patterns)


def extract_max_weight(text):
    """상한 체중(kg). 못 찾으면 None."""
    if not text:
        return None
    m = WEIGHT_MAX_RE.search(text)
    if m:
        return float(m.group(1))
    # "이하" 없이 숫자만 있는 경우 — 상한으로 단정하지 않고 보류
    return None


def extract_size(text):
    """소형/중형/대형. 못 찾으면 None."""
    if not text:
        return None
    for size, words in SIZE_MAP.items():
        if find_any(text, words):
            return size
    return None


def extract_required_items(text):
    """준비물 이름 리스트"""
    if not text:
        return []
    return [name for name, words in REQUIRED_ITEMS.items() if find_any(text, words)]


def split_items(text):
    """쉼표·슬래시로 나열된 품목 문자열을 리스트로"""
    if not text or not text.strip():
        return []
    parts = re.split(r"[,/·\n]|\s{2,}", text)
    return [p.strip() for p in parts if p.strip()]
