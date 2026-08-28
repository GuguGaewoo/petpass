#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
정규화 — TourAPI 자연어 조건문을 구조화 스키마로 변환.

서비스의 핵심 차별점. 기능설명서 #조건_해석 항목이 가리키는 코드다.
스키마 정의는 docs/schema.md 가 기준이며, Dart 판정 엔진과 반드시 일치해야 한다.

실행:
    python normalize.py
"""

import json
import os
import re
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rules import patterns as P
from tourapi import (
    DATA_DIR, NORMALIZED_FILE, cid_of, load_json, merged_records, save_json,
)

# v3: 맹견 조건부 입마개(muzzle_if_fierce) 추가, 배변봉투 회수
SCHEMA_VERSION = 3

CONDITION_FIELDS = [
    "acmpyTypeCd", "acmpyPsblCpam", "acmpyNeedMtr", "relaAcdntRiskMtr",
    "relaPosesFclty", "relaFrnshPrdlst", "relaRntlPrdlst", "relaPurcPrdlst",
    "etcAcmpyInfo",
]

CONTENT_TYPE = {
    "12": "관광지", "14": "문화시설", "15": "행사",
    "28": "레포츠", "32": "숙박", "38": "쇼핑", "39": "음식점",
}


def _homepage(raw):
    """홈페이지 필드는 <a href="..."> 형태로 오는 경우가 많다. URL 만 뽑는다."""
    if not raw:
        return ""
    m = re.search(r'href=["\']?(https?://[^"\'>\s]+)', str(raw))
    if m:
        return m.group(1)
    m = re.search(r'https?://[^\s<"]+', str(raw))
    return m.group(0) if m else ""


def _iso(yyyymmddhhmmss):
    s = str(yyyymmddhhmmss or "").strip()
    if len(s) < 8:
        return None
    try:
        return datetime.strptime(s[:14].ljust(14, "0"), "%Y%m%d%H%M%S").isoformat()
    except ValueError:
        return None


# 국문 관광정보 상세.
# 반려동물 동반여행 서비스는 동반 조건만 주고 개요나 홈페이지를 주지 않는다.
# 같은 contentId 로 조회한 결과를 병합해 상세 화면을 채운다.
#
# 실측 채움률: 개요 94%, 홈페이지 76%, 대표이미지 73%, 전화번호 0%
# 전화번호는 한 건도 없어 화면에서 제외했다.
_KOR = load_json(os.path.join(DATA_DIR, "kor_detail.json"), {})


def normalize(rec):
    """병합된 원본 레코드 1건 → 구조화 스키마 1건"""
    _kor = _KOR.get(cid_of(rec)) or {}

    acmpy_raw = (rec.get("acmpyTypeCd") or "").strip()
    cpam = (rec.get("acmpyPsblCpam") or "").strip()
    need = (rec.get("acmpyNeedMtr") or "").strip()
    etc = (rec.get("etcAcmpyInfo") or "").strip()

    has_detail = bool(acmpy_raw or cpam or need)

    # ── 동반 유형 (판정 1차) ──
    acmpy_type = P.ACMPY_TYPE_MAP.get(acmpy_raw)
    if acmpy_type is None and acmpy_raw:
        acmpy_type = "unknown_value"

    # ── 안내견 전용 (판정 2차, 최우선 제약) ──
    guide_dog_only = P.find_any(cpam, P.GUIDE_DOG_ONLY)

    # ── 명시적 불가 / 문의 필요 ──
    explicitly_denied = cpam in P.NOT_ALLOWED
    needs_inquiry = P.find_any(cpam, P.ASK_PHONE)

    # ── 체중: acmpyPsblCpam 만 확정값으로 인정 ──
    # etcAcmpyInfo 의 체중은 구역별 예외가 섞여 있어 단일 상한으로 쓰면 오판정
    # (예: "산림욕장은 전견종 가능하나 캠핑장은 15Kg이상 불가")
    max_weight = P.extract_max_weight(cpam)
    weight_source = "acmpyPsblCpam" if max_weight is not None else None
    weight_in_etc = max_weight is None and P.extract_max_weight(etc) is not None

    # 입마개: 체중 조건과 견종 조건은 별개다.
    #   "N kg 이상 입마개"      -> 체중 조건 (muzzle_over_kg)
    #   "맹견의 경우 입마개"     -> 견종 조건 (muzzle_if_fierce)
    #   "맹견 및 대형견의 경우"  -> 둘 다. 대형견 경계 25kg 을 임계값으로
    #
    # 각 정규식은 반드시 단일 필드에만 적용한다. source_text 를 이어붙이면
    # cpam 의 "맹견 제외" 와 need 의 "입마개 착용" 이 필드 경계를 넘어
    # "맹견 ... 입마개" 로 오탐된다.
    muzzle_over_kg = (
        P.extract_muzzle_threshold(cpam)
        or P.extract_muzzle_threshold(etc)
        or P.extract_muzzle_large_threshold(cpam)
        or P.extract_muzzle_large_threshold(etc)
    )
    muzzle_if_fierce = (
        P.extract_muzzle_if_fierce(cpam) or P.extract_muzzle_if_fierce(etc)
    )

    max_count = P.extract_max_count(cpam) or P.extract_max_count(etc)

    # ── 견종 ──
    all_breed = P.find_any(cpam, P.ALL_BREED)
    size_limit = None if all_breed else P.extract_size(cpam)
    fierce_excluded = P.extract_fierce_excluded(cpam) or P.extract_fierce_excluded(etc)

    # 필드 간 모순 해소.
    # acmpyPsblCpam 에 "맹견 제외" 가 있는데 etcAcmpyInfo 에는 "맹견의 경우
    # 입마개" 가 있는 경우가 있다(실측 1건). 후자는 295건에 동일하게 박힌
    # 정형 문구이고 전자는 그 장소가 직접 기재한 값이므로 전자가 우선한다.
    # 맹견이 아예 못 들어가는 곳에서 입마개 조건은 의미가 없다.
    if fierce_excluded:
        muzzle_if_fierce = False

    # ── 준비물 ──
    items, free_use, see_etc = P.extract_need_items(need)
    if P.find_any(cpam, P.KENNEL_IN_CPAM) and "이동장" not in items:
        items.append("이동장")     # 가능동물 문구에만 이동장 조건이 있는 경우
    vaccine_required = P.find_any(cpam, P.VACCINE) or P.find_any(etc, P.VACCINE)
    if vaccine_required and "예방접종 증명" not in items:
        items.append("예방접종 증명")

    provided = P.split_items(rec.get("relaFrnshPrdlst"))

    # ── 배변봉투 ──
    # 실측 358건이 언급하는데 규칙이 없어 전량 유실되고 있었다.
    # 별도 필드를 만들지 않고 required_items 에 넣는다. 동물보호법상 장소와
    # 무관한 소유자 의무이므로, Dart 판정 엔진의 baselineItems 가 등급에
    # 반영하지 않고 "기본" 으로 표시한다. 스키마 변경을 최소화하는 방식이다.
    poop_bag, poop_provided = P.extract_poop_bag(etc)
    if not poop_bag:
        poop_bag, poop_provided = P.extract_poop_bag(cpam)
    if any("배변" in i for i in provided):
        poop_bag, poop_provided = True, True   # 비치 품목에 이미 있음
    if poop_bag and "배변봉투" not in items:
        items.append("배변봉투")
    if poop_provided and not any("배변" in i for i in provided):
        provided.append("배변봉투")

    # ── 구역 제한 ──
    # 일부구역인데 어느 구역인지는 자연어로만 있음 → 원문 확인 유도 플래그
    zone_detail_in_text = acmpy_type == "partial_area" and bool(etc)

    # ── 신뢰도 ──
    signals = [
        bool(acmpy_type and acmpy_type != "unknown_value"),
        bool(cpam),
        bool(need),
        all_breed or max_weight is not None or size_limit is not None,
    ]
    confidence = round(sum(1 for s in signals if s) / len(signals), 2)
    if weight_in_etc or see_etc:
        confidence = round(max(confidence - 0.25, 0.0), 2)

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
        "image": rec.get("firstimage") or _kor.get("firstimage") or "",

        # 국문 관광정보 보강
        "overview": (_kor.get("overview") or "").strip(),
        "homepage": _homepage(_kor.get("homepage")),

        # 구조화된 제약 조건
        "has_detail": has_detail,
        "acmpy_type": acmpy_type,
        "guide_dog_only": guide_dog_only,
        "explicitly_denied": explicitly_denied,
        "needs_inquiry": needs_inquiry,
        "all_breed_ok": all_breed,
        "max_weight_kg": max_weight,
        "weight_source": weight_source,
        "weight_in_etc_only": weight_in_etc,
        "size_limit": size_limit,
        "fierce_excluded": fierce_excluded,
        "muzzle_over_kg": muzzle_over_kg,
        "muzzle_if_fierce": muzzle_if_fierce,
        "max_count": max_count,
        "required_items": items,
        "free_use": free_use,
        "see_etc_info": see_etc,
        "zone_detail_in_text": zone_detail_in_text,
        "provided_items": provided,
        "rental_items": P.split_items(rec.get("relaRntlPrdlst")),
        "purchasable_items": P.split_items(rec.get("relaPurcPrdlst")),
        "facilities": P.split_items(rec.get("relaPosesFclty")),
        "extra_fee": P.find_any(etc, P.EXTRA_FEE),
        "outdoor_only": P.extract_outdoor_only(etc) or P.extract_outdoor_only(cpam),
        "risk_notes": (rec.get("relaAcdntRiskMtr") or "").strip(),
        "etc_info": etc,

        # 근거 및 추적 (판정 화면에 반드시 함께 노출)
        "source_text": {f: (rec.get(f) or "") for f in CONDITION_FIELDS},
        "last_modified": _iso(rec.get("modifiedtime")),
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "confidence": confidence,
    }


def main():
    records = merged_records()
    if not records:
        print("수집 데이터가 없습니다. python sync.py collect 를 먼저 실행하세요.")
        return

    out = [normalize(r) for r in records]
    save_json(NORMALIZED_FILE, out)
    n = len(out)

    def cnt(fn):
        return sum(1 for r in out if fn(r))

    trap = cnt(lambda r: r["guide_dog_only"] and r["acmpy_type"] in ("all_area", "partial_area"))
    unknown = sorted({r["source_text"]["acmpyTypeCd"] for r in out
                      if r["acmpy_type"] == "unknown_value"})

    print(f"정규화 {n}건 → {os.path.basename(NORMALIZED_FILE)}\n")
    print("── 판정 가능성 ──")
    print(f"  상세정보 있음          {cnt(lambda r: r['has_detail']):>4}건")
    print(f"  전 견종 허용           {cnt(lambda r: r['all_breed_ok']):>4}건")
    print(f"  체중 상한 확정         {cnt(lambda r: r['max_weight_kg'] is not None):>4}건")
    print(f"  견종 크기 제한         {cnt(lambda r: r['size_limit']):>4}건")
    print(f"  준비물 추출            {cnt(lambda r: r['required_items']):>4}건")

    def has(r, kw):
        return any(kw in i for i in r["required_items"])

    print("\n── 조건절 회수 (v3 신규) ──")
    print(f"  맹견 조건부 입마개     {cnt(lambda r: r['muzzle_if_fierce']):>4}건")
    print(f"  체중 조건부 입마개     {cnt(lambda r: r['muzzle_over_kg'] is not None):>4}건")
    print(f"  입마개 무조건 요구     {cnt(lambda r: has(r, '입마개')):>4}건")
    print(f"  배변봉투 요구          {cnt(lambda r: has(r, '배변봉투')):>4}건")
    print(f"   └ 현장 비치           {cnt(lambda r: any('배변' in i for i in r['provided_items'])):>4}건")
    print(f"  목줄 요구              {cnt(lambda r: has(r, '목줄')):>4}건")
    print(f"  맹견 배제              {cnt(lambda r: r['fierce_excluded']):>4}건")

    print("\n── 주의가 필요한 케이스 ──")
    print(f"  안내견 전용            {cnt(lambda r: r['guide_dog_only']):>4}건")
    print(f"   └ 유형은 '동반가능'    {trap:>4}건  ← 오인 위험")
    print(f"  일부구역(원문 확인)    {cnt(lambda r: r['zone_detail_in_text']):>4}건  ← 최다 헛걸음 요인")
    print(f"  체중이 기타정보에만    {cnt(lambda r: r['weight_in_etc_only']):>4}건")
    print(f"  전화문의 필요          {cnt(lambda r: r['needs_inquiry']):>4}건")
    print(f"  명시적 불가            {cnt(lambda r: r['explicitly_denied']):>4}건")

    avg = sum(r["confidence"] for r in out) / n
    print(f"\n  평균 신뢰도            {avg:.2f}")

    if unknown:
        print("\n⚠ ACMPY_TYPE_MAP 에 없는 값:")
        for v in unknown:
            print(f"    {v!r}")


if __name__ == "__main__":
    main()
