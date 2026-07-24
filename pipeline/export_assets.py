#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flutter 에셋 JSON 생성기.

정규화 결과(pet_normalized.json)에서 앱이 실제로 쓰는 필드만 추려
app/assets/places.json 을 만든다.

왜 DB 가 아니라 에셋인가:
  Supabase 무료 플랜은 7일간 활동이 없으면 프로젝트가 일시정지된다.
  개발이 9월에 끝나고 심사가 10월이면 심사 시점에 정지돼 있을 수 있다.
  장소 데이터를 앱에 번들하면 그 위험이 사라지고, 문서 3번의 설계 원칙
  ("API 데이터만으로도 서비스가 완전히 동작해야 한다")이 아키텍처로 강제된다.
  632건은 클라이언트 메모리에서 필터링·판정하기에 충분히 작다.

실행:
    python export_assets.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tourapi import NORMALIZED_FILE, load_json, save_json

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "app", "assets", "places.json")

# 앱이 쓰지 않는 필드 — 채움률이 낮거나 판정/표시에 관여하지 않는다
DROP_FIELDS = {
    "schema_version",      # 파일 상단 메타로 한 번만 기록
    "collected_at",        # last_modified 로 충분
    "rental_items",        # 채움률 2.7%
    "purchasable_items",   # 채움률 3.3%
    "sigungu_code",        # 현재 화면에서 미사용
    "weight_source",       # 디버깅용
}

# 값이 아래와 같으면 키 자체를 뺀다 (기본값이므로 앱에서 복원 가능)
DEFAULTS = {
    False: {"guide_dog_only", "explicitly_denied", "needs_inquiry", "all_breed_ok",
            "weight_in_etc_only", "fierce_excluded", "free_use", "see_etc_info",
            "zone_detail_in_text", "extra_fee", "outdoor_only"},
}


def slim(rec):
    out = {}
    for k, v in rec.items():
        if k in DROP_FIELDS:
            continue
        if v is None or v == "" or v == [] or v == {}:
            continue
        if v is False and k in DEFAULTS[False]:
            continue
        if k == "source_text":
            # 빈 원문 필드는 버린다
            v = {kk: vv for kk, vv in v.items() if vv}
            if not v:
                continue
        out[k] = v
    return out


def main():
    rows = load_json(NORMALIZED_FILE, [])
    if not rows:
        print("normalize.py 를 먼저 실행하세요.")
        return

    slimmed = [slim(r) for r in rows]
    payload = {
        "schema_version": rows[0].get("schema_version", 2),
        "count": len(slimmed),
        "source": "한국관광공사 TourAPI (KorPetTourService2)",
        "places": slimmed,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # 에셋은 사람이 읽을 일이 없으므로 공백 없이 최소 크기로 저장
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))

    size = os.path.getsize(OUT)
    before = os.path.getsize(NORMALIZED_FILE)
    print(f"에셋 생성 완료 → app/assets/places.json")
    print(f"  장소 {len(slimmed)}건")
    print(f"  {before/1024:.0f}KB → {size/1024:.0f}KB  ({size/before*100:.0f}%)")

    # 필드별 사용 현황 — 더 뺄 게 있는지 확인용
    from collections import Counter
    keys = Counter()
    for r in slimmed:
        keys.update(r.keys())
    print("\n  포함 필드 (건수)")
    for k, c in keys.most_common():
        print(f"    {k:<22} {c:>4}")


if __name__ == "__main__":
    main()
