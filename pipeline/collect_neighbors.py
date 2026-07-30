#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
주변 장소 사전 수집 — F-07(주변 탐색) / F-08(일정 추천) 의 데이터 원천.

632개 장소 각각에 국문 관광정보 위치기반 조회를 1회씩 돌린다.
오퍼레이션당 1일 1,000건 한도 안에 들어간다.

목적은 런타임 API 호출을 0회로 만드는 것이다. 앱 실행 중에는 저장된
이웃 목록만 읽으므로 오프라인에서도 일정 추천이 동작한다.

주의: 이웃에 대해 추가 상세 조회를 하지 않는다. 위치기반 조회 응답에
      이름·좌표·주소·타입·이미지URL이 있어 일정 생성에 충분하다.
      여기서 상세를 또 부르면 632 x 30 = 약 19,000회로 폭발한다.

실행:
    python collect_neighbors.py          # 수집 (중단 시 재실행하면 이어서)
    python collect_neighbors.py stats    # 결과만 확인
"""

import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tourapi import (
    DATA_DIR, KOR_BASE, SLEEP, call, cid_of, load_json,
    merged_records, require_key, save_json,
)

NEIGHBOR_FILE = os.path.join(DATA_DIR, "neighbors.json")
KOR_OP_LOCATION = "locationBasedList2"

RADIUS_M = 20000   # API 최대 반경. 더 크게 요청해도 잘린다
PER_PLACE = 30     # 장소당 이웃 수
ARRANGE = "E"      # 거리순. 가까운 곳부터 받아야 클러스터링이 의미 있다

# 일정 시간대 배치에 쓰는 유형만 남긴다.
# 행사(15)는 기간이 지나면 무의미해지므로 제외한다.
KEEP_TYPES = {"12", "14", "28", "32", "38", "39"}


def haversine_m(lat1, lng1, lat2, lng2):
    """API 가 dist 를 안 줄 때의 보정용. 미터 단위."""
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return int(2 * r * math.asin(math.sqrt(a)))


def main():
    require_key()
    base = merged_records()
    if not base:
        print("수집 데이터가 없습니다. python sync.py collect 를 먼저 실행하세요.")
        return

    # 반려동물 동반 장소의 contentId 집합.
    # 이웃이 이 집합에 있으면 판정 가능한 곳 = 일정 후보다.
    pet_ids = {cid_of(r) for r in base if cid_of(r)}

    targets = [r for r in base if r.get("mapx") and r.get("mapy")]
    print("대상 {}건 (좌표 없음 {}건 제외)".format(len(targets), len(base) - len(targets)))

    done = load_json(NEIGHBOR_FILE, {})
    todo = [r for r in targets if cid_of(r) not in done]
    print("수집 대상 {}건 (기존 {}건 완료)\n".format(len(todo), len(done)))
    if not todo:
        stats(done, pet_ids)
        return

    fails, streak = 0, 0
    try:
        for i, r in enumerate(todo, 1):
            cid = cid_of(r)
            lat, lng = float(r["mapy"]), float(r["mapx"])
            try:
                items, _ = call(
                    KOR_BASE, KOR_OP_LOCATION,
                    mapX=lng, mapY=lat, radius=RADIUS_M,
                    numOfRows=PER_PLACE + 10, pageNo=1, arrange=ARRANGE,
                )
                streak = 0
            except Exception as e:
                fails += 1
                streak += 1
                print("  {} 실패: {}".format(cid, str(e)[:60]))
                if streak >= 10:
                    print("\n[중단] 연속 10회 실패 - 한도 초과이거나 API 장애로 보입니다.")
                    print("  다시 실행하면 실패분부터 재시도합니다.")
                    break
                time.sleep(SLEEP)
                continue

            out = []
            for it in items:
                ncid = cid_of(it)
                if not ncid or ncid == cid:
                    continue
                ntype = str(it.get("contenttypeid") or "")
                if ntype not in KEEP_TYPES:
                    continue
                try:
                    nlat, nlng = float(it["mapy"]), float(it["mapx"])
                except (KeyError, TypeError, ValueError):
                    continue
                try:
                    dist = int(float(it.get("dist")))
                except (TypeError, ValueError):
                    dist = haversine_m(lat, lng, nlat, nlng)
                out.append({
                    "content_id": ncid,
                    "title": it.get("title") or "",
                    "content_type_id": ntype,
                    "lat": nlat,
                    "lng": nlng,
                    "address": " ".join(
                        x for x in [it.get("addr1"), it.get("addr2")] if x).strip(),
                    "image": it.get("firstimage") or "",
                    "distance_m": dist,
                    # 동반 데이터가 있는 곳만 판정 가능. 일정 추천은 이것만 후보로 삼는다
                    "pet_data": ncid in pet_ids,
                })
                if len(out) >= PER_PLACE:
                    break

            done[cid] = out
            if i % 50 == 0:
                save_json(NEIGHBOR_FILE, done)
                print("  {}/{} ... 저장".format(i, len(todo)))
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 - 여기까지 저장합니다.")

    save_json(NEIGHBOR_FILE, done)
    left = len([r for r in targets if cid_of(r) not in done])
    print("\n이웃 {}건 -> {}  (미수집 {}건, 실패 {}건)".format(
        len(done), os.path.basename(NEIGHBOR_FILE), left, fails))
    stats(done, pet_ids)


def stats(done=None, pet_ids=None):
    if done is None:
        done = load_json(NEIGHBOR_FILE, {})
        if not done:
            print("수집 결과가 없습니다.")
            return
    if pet_ids is None:
        pet_ids = {cid_of(r) for r in merged_records() if cid_of(r)}

    counts = [len(v) for v in done.values()]
    pets = [sum(1 for n in v if n["pet_data"]) for v in done.values()]
    kb = os.path.getsize(NEIGHBOR_FILE) / 1024 if os.path.exists(NEIGHBOR_FILE) else 0
    n = max(len(counts), 1)

    print("\n-- 이웃 수집 결과 --")
    print("  기준 장소            {:>5}건".format(len(done)))
    print("  이웃 총합            {:>5}건".format(sum(counts)))
    print("  장소당 평균          {:>7.1f}건".format(sum(counts) / n))
    print("  이웃 0건             {:>5}건".format(sum(1 for c in counts if c == 0)))
    print("")
    print("  동반 가능 이웃 총합  {:>5}건".format(sum(pets)))
    print("  장소당 평균          {:>7.1f}건".format(sum(pets) / n))
    print("  동반 이웃 0건        {:>5}건   <- 일정 생성 불가".format(
        sum(1 for c in pets if c == 0)))
    print("  동반 이웃 3건 미만   {:>5}건   <- 일정이 빈약해지는 장소".format(
        sum(1 for c in pets if c < 3)))
    print("")
    print("  파일 크기            {:>7.0f} KB".format(kb))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "stats":
        stats()
    else:
        main()
