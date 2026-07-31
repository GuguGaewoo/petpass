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
from collect_neighbors import NEIGHBOR_FILE

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "app", "assets", "places.json")

NEIGHBOR_OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "app", "assets", "neighbors.json")

# 일정 후보에서 제외할 유형.
#   restricted — 어린이공원 등 동반이 실제로 막힌 곳
#   indoor     — 실내 시설
# unknown 은 남긴다. 유형을 판별하지 못했을 뿐 동반 가능한 곳이 섞여 있고,
# 무엇보다 앱에 존재하지 않으면 사용자가 제보할 대상조차 되지 못한다(F-10).
NEIGHBOR_DROP_KINDS = {"restricted", "indoor"}

# 장소당 이웃 수. 중앙값이 19건이므로 20건이면 하루 일정에 충분하다.
NEIGHBOR_LIMIT = 20

# 앱에 보내지 않는 이웃 필드. cat 코드는 분류에만 쓰고 화면에서는 안 본다.
NEIGHBOR_DROP_FIELDS = {"cat1", "cat2", "cat3"}

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
            "zone_detail_in_text", "extra_fee", "outdoor_only",
            "muzzle_if_fierce"},
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


def export_neighbors():
    """주변 장소 — F-07(주변 탐색) / F-08(일정 추천) 용.

    places.json 과 별도 파일로 둔다. 앱 시작 시점에 읽지 않고
    사용자가 해당 기능에 진입할 때만 지연 로딩한다.
    """
    data = load_json(NEIGHBOR_FILE, {})
    if not data:
        print("collect_neighbors.py 를 먼저 실행하세요.")
        return None

    # F-10 확장 지점:
    #   제보로 확정된 정보가 있으면 여기서 병합한다.
    #   ov = load_json(OVERRIDE_FILE, {})   # {content_id: {"place_kind": "outdoor"}}
    #   자동 반영이 아니라 수동 검토를 거친 것만 넣는다. 제보를 그대로 믿으면
    #   누구나 데이터를 오염시킬 수 있고, 근거 없는 판정이 된다.
    #   병합된 건은 TourAPI 근거가 없으므로 판정 뱃지를 주지 않고
    #   일정 우선순위만 올린다. 화면에는 "이용자 제보"로 표시한다.

    out, kept, dropped = {}, 0, 0
    for cid, lst in data.items():
        keep = []
        for n in lst:
            if n.get("place_kind") in NEIGHBOR_DROP_KINDS:
                dropped += 1
                continue
            keep.append({k: v for k, v in n.items()
                         if k not in NEIGHBOR_DROP_FIELDS and v not in (None, "", [], {})})
            if len(keep) >= NEIGHBOR_LIMIT:
                break
        out[cid] = keep
        kept += len(keep)

    payload = {"count": len(out), "neighbors": out}
    os.makedirs(os.path.dirname(NEIGHBOR_OUT), exist_ok=True)
    with open(NEIGHBOR_OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))

    size = os.path.getsize(NEIGHBOR_OUT)
    before = os.path.getsize(NEIGHBOR_FILE)
    print("\n이웃 에셋 생성 완료 -> app/assets/neighbors.json")
    print("  기준 장소 {}건, 이웃 {}건 (제외 {}건)".format(len(out), kept, dropped))
    print("  {:.0f}KB -> {:.0f}KB  ({:.0f}%)".format(
        before / 1024, size / 1024, size / before * 100))

    per = sorted(len(v) for v in out.values())
    m = len(per)
    print("  장소당 평균 {:.1f}건 / 중앙값 {}건 / 최소 {}건".format(
        sum(per) / max(m, 1), per[m // 2] if m else 0, per[0] if m else 0))
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

    export_neighbors()


if __name__ == "__main__":
    main()
