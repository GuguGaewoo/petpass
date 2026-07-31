#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
이웃 장소 유형 분류 — 야외 공간 여부를 판별한다.

B안(이웃 전체를 일정 후보로 사용)에서 "동반 정보 없음" 장소들의
우선순위를 가르기 위한 힌트다.

중요: 이것은 판정이 아니다.
  동반 데이터가 없는 곳에 "야외 공간이므로 동반 가능"이라고 단정하면
  근거 없는 판정이 된다. 4단계 뱃지는 동반 데이터가 있는 곳에만 붙이고,
  이 값은 일정 배치 우선순위와 화면 라벨에만 관여한다.

분류 우선순위:
  1) 콘텐츠 유형이 확정적인 경우 (음식점, 숙박)
  2) cat1/cat2 분류 코드
  3) 장소명 키워드
  4) contenttypeid 폴백

실행:
    python classify_neighbors.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tourapi import load_json, save_json
from collect_neighbors import NEIGHBOR_FILE

# ── TourAPI 분류 코드 ─────────────────────────────────
CAT1_OUTDOOR = ("A01",)     # 자연 — 전부 야외
CAT2_OUTDOOR = ("A0202",)   # 휴양관광지 — 공원, 유원지, 자연휴양림
CAT2_INDOOR = ("A0206",)    # 문화시설 — 박물관, 미술관, 전시관

# ── 장소명 키워드 ─────────────────────────────────────
OUTDOOR_WORDS = [
    "해수욕장", "해변", "해안", "바닷가", "방파제", "등대", "포구",
    "공원", "광장", "잔디", "정원", "수목원", "식물원", "화원",
    "둘레길", "산책로", "숲길", "올레", "나들길", "자락길", "탐방로",
    "트레킹", "등산로", "자연휴양림", "휴양림", "산림욕장", "숲",
    "계곡", "폭포", "동굴", "전망대", "호수", "저수지", "강변",
    "천변", "습지", "생태", "유원지", "캠핑", "야영", "글램핑",
    "목장", "농장", "체험마을", "수변", "둔치", "야외",
]

# 야외지만 반려동물 출입이 제한되는 곳.
# 어린이 놀이시설은 안전관리법과 지자체 조례로 동반을 금지하는 경우가 많다.
# 야외라는 이유로 일정에 넣으면 오히려 헛걸음을 유도하게 된다.
RESTRICTED_WORDS = [
    "어린이공원", "어린이놀이터", "놀이터", "유아", "어린이대공원",
    "학교", "유치원", "어린이집", "운동장", "체육관",
]

INDOOR_WORDS = [
    "박물관", "미술관", "전시관", "기념관", "과학관", "도서관",
    "아쿠아리움", "수족관", "영화관", "극장", "공연장", "문화원",
    "실내", "백화점", "아울렛", "마트", "쇼핑몰",
    "온천", "찜질방", "사우나", "스파",
    "성당", "교회", "법당", "향교", "서원",
    "타워", "전망타워", "몰", "플라자", "터미널", "역사",
    "관광특구", "면세점", "시장", "상가", "카페", "베이커리",
]

TYPE_FALLBACK = {
    "12": "unknown", "14": "indoor", "28": "unknown",
    "32": "lodging", "38": "indoor", "39": "dining",
}

LABEL = {
    "outdoor": "야외 공간", "indoor": "실내 시설",
    "lodging": "숙박", "dining": "음식점", "restricted": "동반 제한", "unknown": "유형 미상",
}


def classify(n):
    """이웃 1건 -> place_kind

    순서가 곧 로직이다. cat 코드는 원본 데이터의 분류라
    "롯데월드 아쿠아리움"이 A0202(휴양관광지)로 등록되는 등
    실제 성격과 어긋나는 경우가 있다. 장소명의 명시적 키워드가
    분류 코드보다 신뢰도가 높으므로 키워드를 먼저 본다.
    """
    ctype = str(n.get("content_type_id") or "")
    title = n.get("title") or ""

    # 1) 유형이 확정적인 것
    if ctype in ("39", "32"):
        return TYPE_FALLBACK[ctype]

    # 2) 동반 제한. 야외여도 출입이 막힌 곳이므로 최우선 배제
    for w in RESTRICTED_WORDS:
        if w in title:
            return "restricted"

    # 3) 실내 키워드. cat 코드보다 앞선다
    for w in INDOOR_WORDS:
        if w in title:
            return "indoor"

    # 4) 야외 키워드
    for w in OUTDOOR_WORDS:
        if w in title:
            return "outdoor"

    # 5) cat 코드 — 키워드로 판별되지 않은 것만
    c1 = str(n.get("cat1") or "")
    c2 = str(n.get("cat2") or "")
    if c2.startswith(CAT2_INDOOR):
        return "indoor"
    if c1.startswith(CAT1_OUTDOOR) or c2.startswith(CAT2_OUTDOOR):
        return "outdoor"

    return TYPE_FALLBACK.get(ctype, "unknown")

def main():
    data = load_json(NEIGHBOR_FILE, {})
    if not data:
        print("neighbors.json 이 없습니다. collect_neighbors.py 를 먼저 실행하세요.")
        return

    has_cat = any(n.get("cat1") for lst in data.values() for n in lst)
    tally = {}
    for lst in data.values():
        for n in lst:
            k = classify(n)
            n["place_kind"] = k
            tally[k] = tally.get(k, 0) + 1

    save_json(NEIGHBOR_FILE, data)
    total = sum(tally.values())

    print("분류 완료 — 기준 장소 {}건, 이웃 {}건".format(len(data), total))
    print("근거: {}\n".format("cat 코드 + 장소명" if has_cat else "장소명만 (cat 코드 없음)"))

    print("-- 유형 분포 --")
    for k in ("outdoor", "dining", "lodging", "indoor", "restricted", "unknown"):
        c = tally.get(k, 0)
        print("  {:<10} {:>6}건  {:>5.1f}%".format(LABEL[k], c, c / max(total, 1) * 100))

    pet = sum(1 for lst in data.values() for n in lst if n.get("pet_data"))
    print("\n-- 일정 후보군 --")
    print("  동반 데이터 있음     {:>6}건".format(pet))
    print("  야외 공간            {:>6}건".format(tally.get("outdoor", 0)))
    print("  음식점               {:>6}건".format(tally.get("dining", 0)))

    per = [sum(1 for n in lst
               if n.get("pet_data") or n["place_kind"] in ("outdoor", "dining"))
           for lst in data.values()]
    per.sort()
    n = len(per)
    print("\n-- 기준 장소당 후보 수 --")
    print("  평균                 {:>6.1f}건".format(sum(per) / max(n, 1)))
    print("  중앙값               {:>6}건  <- 10 이상이면 일정 충분".format(per[n // 2] if n else 0))
    print("  최소                 {:>6}건".format(per[0] if n else 0))
    print("  후보 5건 미만        {:>6}곳".format(sum(1 for c in per if c < 5)))
    print("  후보 0건             {:>6}곳  <- 일정 생성 불가".format(sum(1 for c in per if c == 0)))

    # 야외로 분류된 것들이 실제로 그럴듯한지 눈으로 확인
    seen, sample = set(), []
    for lst in data.values():
        for x in lst:
            if x["place_kind"] == "outdoor" and x["content_id"] not in seen:
                seen.add(x["content_id"])
                sample.append(x["title"])
            if len(sample) >= 15:
                break
        if len(sample) >= 15:
            break
    print("\n-- 야외 분류 샘플 --")
    for t in sample:
        print("  " + t)


if __name__ == "__main__":
    main()
