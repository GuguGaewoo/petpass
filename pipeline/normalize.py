#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
정규화 — TourAPI 자연어 조건문을 구조화 스키마로 변환.

서비스의 핵심 차별점이 여기 있습니다. 기능설명서의 #조건_해석 항목이
가리키는 코드입니다.

스키마 정의는 docs/schema.md 가 기준입니다. 이 파일과 app/lib/domain/ 의
Dart 모델이 같은 스키마를 봐야 하므로, 필드를 바꿀 때는 문서를 먼저 고치세요.

실행:
    python normalize.py          # data/pet_normalized.json 생성
"""

import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rules import patterns as P
from tourapi import NORMALIZED_FILE, cid_of, merged_records, save_json

SCHEMA_VERSION = 1

# 조건 문구가 들어 있을 수 있는 상세 필드 전체
CONDITION_FIELDS = [
    "acmpyTypeCd", "acmpyPsblCpam", "acmpyNeedMtr", "relaAcdntRiskMtr",
    "relaPosesFclty", "relaFrnshPrdlst", "relaRntlPrdlst", "relaPurcPrdlst",
    "etcAcmpyInfo",
]

CONTENT_TYPE = {
    "12": "관광지", "14": "문화시설", "15": "행사",
    "28": "레포츠", "32": "숙박", "38": "쇼핑", "39": "음식점",
}


def _blob(rec):
    """조건 관련 필드를 하나의 문자열로 합침"""
    return " ".join(str(rec.get(f) or "") for f in CONDITION_FIELDS)


def _iso(yyyymmddhhmmss):
    """TourAPI 의 20241218152408 형식을 ISO 로"""
    s = str(yyyymmddhhmmss or "").strip()
    if len(s) < 8:
        return None
    try:
        return datetime.strptime(s[:14].ljust(14, "0"), "%Y%m%d%H%M%S").isoformat()
    except ValueError:
        return None


def normalize(rec):
    """병합된 원본 레코드 1건 → 구조화 스키마 1건"""
    blob = _blob(rec)
    acmpy_raw = (rec.get("acmpyTypeCd") or "").strip()
    cpam_raw = (rec.get("acmpyPsblCpam") or "").strip()
    need_raw = (rec.get("acmpyNeedMtr") or "").strip()

    has_detail = bool(acmpy_raw or cpam_raw or need_raw)

    # ── 동반 유형 ──
    acmpy_type = P.ACMPY_TYPE_MAP.get(acmpy_raw)
    if acmpy_type is None and acmpy_raw:
        acmpy_type = "unknown_value"      # 매핑에 없는 새 값 → patterns.py 보강 필요

    # ── 안내견 전용 여부 (핵심) ──
    # acmpyTypeCd 가 "동반가능" 이어도 여기가 True 면 일반 반려견은 불가.
    guide_dog_only = P.find_any(cpam_raw, P.GUIDE_DOG_ONLY)

    # ── 체중 / 크기 ──
    max_weight = P.extract_max_weight(cpam_raw) or P.extract_max_weight(blob)
    size = P.extract_size(cpam_raw) or P.extract_size(blob)

    # ── 준비물 ──
    required = P.extract_required_items(need_raw)
    for extra in P.extract_required_items(blob):
        if extra not in required:
            required.append(extra)

    # ── 신뢰도 ──
    # 구조화에 성공한 신호가 많을수록 높음. UI 에서 "정보없음" 판단에 사용.
    signals = [bool(acmpy_type), bool(cpam_raw), bool(need_raw),
               max_weight is not None, size is not None]
    confidence = round(sum(1 for s in signals if s) / len(signals), 2)

    return {
        "schema_version": SCHEMA_VERSION,
        "content_id": cid_of(rec),

        # 장소 기본 정보
        "title": rec.get("title") or "",
        "address": " ".join(x for x in [rec.get("addr1"), rec.get("addr2")] if x).strip(),
        "content_type": CONTENT_TYPE.get(str(rec.get("contenttypeid")), "기타"),
        "content_type_id": str(rec.get("contenttypeid") or ""),
        "area_code": str(rec.get("areacode") or ""),
        "sigungu_code": str(rec.get("sigungucode") or ""),
        "lat": float(rec["mapy"]) if rec.get("mapy") else None,
        "lng": float(rec["mapx"]) if rec.get("mapx") else None,
        "tel": rec.get("tel") or "",
        "image": rec.get("firstimage") or "",

        # 구조화된 제약 조건
        "has_detail": has_detail,
        "acmpy_type": acmpy_type,
        "guide_dog_only": guide_dog_only,
        "max_weight_kg": max_weight,
        "size_restriction": size,
        "breed_restricted": P.find_any(blob, P.BREED_RESTRICTED),
        "required_items": required,
        "provided_items": P.split_items(rec.get("relaFrnshPrdlst")),
        "rental_items": P.split_items(rec.get("relaRntlPrdlst")),
        "purchasable_items": P.split_items(rec.get("relaPurcPrdlst")),
        "facilities": P.split_items(rec.get("relaPosesFclty")),
        "extra_fee": P.find_any(blob, P.EXTRA_FEE),
        "outdoor_only": P.find_any(blob, P.OUTDOOR_ONLY),
        "risk_notes": (rec.get("relaAcdntRiskMtr") or "").strip(),
        "etc_info": (rec.get("etcAcmpyInfo") or "").strip(),

        # 근거 및 추적 (판정 화면에 반드시 함께 노출)
        "source_text": {f: (rec.get(f) or "") for f in CONDITION_FIELDS},
        "last_modified": _iso(rec.get("modifiedtime")),
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "confidence": confidence,
    }


def main():
    records = merged_records()
    if not records:
        print("수집 데이터가 없습니다. python sync.py 를 먼저 실행하세요.")
        return

    out = [normalize(r) for r in records]
    save_json(NORMALIZED_FILE, out)

    with_detail = sum(1 for r in out if r["has_detail"])
    guide = sum(1 for r in out if r["guide_dog_only"])
    trap = sum(1 for r in out
               if r["guide_dog_only"] and r["acmpy_type"] in ("all_area", "partial_area"))
    weight = sum(1 for r in out if r["max_weight_kg"] is not None)
    unknown = sorted({r["acmpy_type"] for r in out if r["acmpy_type"] == "unknown_value"})

    print(f"정규화 {len(out)}건 → {os.path.basename(NORMALIZED_FILE)}")
    print(f"  상세정보 있음        {with_detail:>5}건 ({with_detail/len(out)*100:.1f}%)")
    print(f"  안내견 전용          {guide:>5}건")
    print(f"   └ 유형은 '동반가능'  {trap:>5}건  ← 오인 위험. 서비스 핵심 사례")
    print(f"  체중 상한 추출 성공  {weight:>5}건")
    if unknown:
        print("\n⚠ ACMPY_TYPE_MAP 에 없는 값이 있습니다. rules/patterns.py 를 보강하세요.")


if __name__ == "__main__":
    main()
