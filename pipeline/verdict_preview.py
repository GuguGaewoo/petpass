#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
판정 분포 미리보기 — 일회성 분석 도구.

⚠ 파이프라인의 일부가 아니다. 판정의 정본은 docs/schema.md 이며
   실제 구현은 app/lib/domain/verdict_engine.dart 가 담당한다.

판정 기준(v2):
    뱃지가 답하는 질문은 "데려가면 들어갈 수 있나?" 하나다.
      불가        데려가면 거부당함
      조건부 가능  준비물이 없으면 거부당할 수 있음
      가능        그냥 가면 됨
      정보없음     판단 근거 부족

    v1 대비 변경:
      - 목줄을 조건에서 제외. 동물보호법상 외출 시 안전조치는 이미 의무이며
        장소 고유의 제약이 아니다. (입마개는 맹견 한정 의무이므로 조건 유지)
      - '일부구역'을 등급 강등 사유에서 제외하고 칩으로 표시.
        일부구역은 입장 거부가 아니라 이용 범위 제한이다.

실행:
    python verdict_preview.py
"""

import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tourapi import NORMALIZED_FILE, load_json

SIZE_ORDER = {"small": 1, "medium": 2, "large": 3}

# 법정 의무이자 반려인 기본 지참품 — 장소 고유 제약이 아니므로 등급을 낮추지 않는다
BASELINE_ITEMS = {"목줄"}

PROFILES = [
    {"name": "말티즈 4kg",        "weight": 4.0,  "size": "small",  "fierce": False},
    {"name": "코커스패니얼 12kg", "weight": 12.0, "size": "medium", "fierce": False},
    {"name": "리트리버 30kg",     "weight": 30.0, "size": "large",  "fierce": False},
]


def judge(p, pet):
    """docs/schema.md 의 판정 규칙 v2. 반환: (등급, 사유)"""
    if not p["has_detail"]:
        return "정보없음", "상세 조건 데이터 없음"
    if p["explicitly_denied"]:
        return "불가", "동반 불가 명시"
    if p["guide_dog_only"]:
        return "불가", "안내견 전용"
    if p["needs_inquiry"]:
        return "정보없음", "전화 문의 필요"

    if p["max_weight_kg"] is not None and pet["weight"] > p["max_weight_kg"]:
        return "불가", f"체중 상한 {p['max_weight_kg']:.0f}kg 초과"
    if p["size_limit"] and SIZE_ORDER[pet["size"]] > SIZE_ORDER[p["size_limit"]]:
        return "불가", f"{p['size_limit']}견까지만 허용"
    if p["fierce_excluded"] and pet["fierce"]:
        return "불가", "맹견 제외"

    # 목줄 외의 준비물이 있으면 조건부 — 안 챙기면 실제로 거부당한다
    extra = [i for i in p["required_items"] if i not in BASELINE_ITEMS]
    if extra:
        return "조건부 가능", "준비물 " + "·".join(extra)
    if p["weight_in_etc_only"] or p["see_etc_info"]:
        return "조건부 가능", "기타 조건 확인 필요"
    if not p["acmpy_type"]:
        return "정보없음", "동반 유형 미기재"
    return "가능", "제약 없음"


def chips(p, pet):
    """등급을 바꾸지는 않지만 카드에 표시할 부가 정보"""
    out = []
    if p["acmpy_type"] == "partial_area":
        out.append("구역 제한")
    if p["max_weight_kg"] is not None:
        out.append(f"{p['max_weight_kg']:.0f}kg 이하")
    if p["fierce_excluded"]:
        out.append("맹견 제외")
    if p["max_count"]:
        out.append(f"최대 {p['max_count']}마리")
    if p["muzzle_over_kg"]:
        out.append(f"{p['muzzle_over_kg']:.0f}kg↑ 입마개")
    if p["extra_fee"]:
        out.append("추가 요금")
    return out


def main():
    rows = load_json(NORMALIZED_FILE, [])
    if not rows:
        print("normalize.py 를 먼저 실행하세요.")
        return
    n = len(rows)

    for pet in PROFILES:
        verdicts, reasons = Counter(), Counter()
        for p in rows:
            v, why = judge(p, pet)
            verdicts[v] += 1
            reasons[(v, why)] += 1

        print(f"\n{'=' * 54}")
        print(f"  {pet['name']}")
        print(f"{'=' * 54}")
        for v in ("가능", "조건부 가능", "불가", "정보없음"):
            c = verdicts[v]
            print(f"  {v:<8} {c:>4}건 ({c/n*100:5.1f}%)  {'█' * int(c / n * 40)}")

        print("\n  주요 사유")
        for (v, why), c in reasons.most_common(7):
            print(f"    {c:>4}건  [{v}] {why}")

    print(f"\n{'=' * 54}")
    print("  칩 출현 빈도 (등급과 별개로 카드에 표시)")
    print(f"{'=' * 54}")
    ch = Counter()
    for p in rows:
        for c in chips(p, PROFILES[0]):
            # 수치가 들어간 칩은 종류만 집계
            key = c if not any(x in c for x in ("kg", "마리")) else c.split()[-1]
            ch[key] += 1
    for c, k in ch.most_common(10):
        print(f"  {c:<14} {k:>4}건 ({k/n*100:4.1f}%)")

    print(f"\n{'=' * 54}")
    print("  준비물 출현 빈도")
    print(f"{'=' * 54}")
    items = Counter()
    for p in rows:
        for it in p["required_items"]:
            items[it] += 1
    for it, c in items.most_common(12):
        tag = "  ← 기본 지참품, 등급 미반영" if it in BASELINE_ITEMS else ""
        print(f"  {it:<14} {c:>4}건 ({c/n*100:4.1f}%){tag}")


if __name__ == "__main__":
    main()