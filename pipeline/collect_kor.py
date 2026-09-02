#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
국문 관광정보 상세 수집 — 전화번호·홈페이지·개요·이미지 보강.

반려동물 동반여행 서비스는 동반 조건만 제공하고 연락처나 개요를 주지 않는다.
같은 contentId 로 국문 관광정보의 공통정보를 조회해 상세 화면을 채운다.

호출 예산: 632회 (오퍼레이션당 1일 1,000건 한도 안)

실행:
    python collect_kor.py          # 수집 (중단 시 재실행하면 이어서)
    python collect_kor.py stats    # 결과만 확인
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tourapi import (
    DATA_DIR, KOR_BASE, SLEEP, call, cid_of, load_json,
    merged_records, require_key, save_json,
)

KOR_FILE = os.path.join(DATA_DIR, "kor_detail.json")
KOR_OP_COMMON = "detailCommon2"

# 앱에서 쓸 필드만 남긴다. 응답에는 40개 넘는 필드가 오지만
# 대부분 비어 있거나 화면에 쓰지 않는다.
# mapx/mapy 는 영문 데이터와 좌표로 매칭할 때 쓴다.
KEEP = [
    "tel", "telname", "homepage", "overview",
    "firstimage", "firstimage2", "zipcode", "mapx", "mapy",
]


def main():
    require_key()
    base = merged_records()
    if not base:
        print("수집 데이터가 없습니다.")
        return

    done = load_json(KOR_FILE, {})
    todo = [cid_of(r) for r in base if cid_of(r) and cid_of(r) not in done]
    print("수집 대상 {}건 (기존 {}건 완료)\n".format(len(todo), len(done)))
    if not todo:
        stats(done)
        return

    fails, streak = 0, 0
    try:
        for i, cid in enumerate(todo, 1):
            try:
                items, _ = call(KOR_BASE, KOR_OP_COMMON, contentId=cid)
                if items:
                    r = items[0]
                    # 빈 값은 저장하지 않는다. 용량과 가독성 모두에 낫다.
                    done[cid] = {
                        k: str(r.get(k) or "").strip()
                        for k in KEEP
                        if str(r.get(k) or "").strip()
                    }
                else:
                    # 결과 없음 = 국문 관광정보에 없는 곳. 재시도를 막는다.
                    done[cid] = {}
                streak = 0
            except Exception as e:
                fails += 1
                streak += 1
                print("  {} 실패: {}".format(cid, str(e)[:55]))
                if streak >= 10:
                    print("\n[중단] 연속 10회 실패")
                    break
            if i % 100 == 0:
                save_json(KOR_FILE, done)
                print("  {}/{} ... 저장".format(i, len(todo)))
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 - 여기까지 저장합니다.")

    save_json(KOR_FILE, done)
    print("\n국문 상세 {}건 -> {}  (실패 {}건)".format(
        len(done), os.path.basename(KOR_FILE), fails))
    stats(done)


def stats(done=None):
    if done is None:
        done = load_json(KOR_FILE, {})
        if not done:
            print("수집 결과가 없습니다.")
            return

    n = len(done)
    print("\n-- 필드별 채움률 --")
    labels = {
        "tel": "전화번호",
        "homepage": "홈페이지",
        "overview": "개요",
        "firstimage": "대표 이미지",
        "mapx": "좌표",
    }
    for k, label in labels.items():
        c = sum(1 for v in done.values() if v.get(k))
        print("  {:10} {:>4}건  ({:>2.0f}%)".format(label, c, c / max(n, 1) * 100))

    empty = sum(1 for v in done.values() if not v)
    print("\n  국문 정보 없음  {:>4}건".format(empty))

    lens = sorted(
        len(v.get("overview", "")) for v in done.values() if v.get("overview")
    )
    if lens:
        print("\n-- 개요 길이 --")
        print("  중앙값 {}자 / 최대 {}자".format(lens[len(lens) // 2], lens[-1]))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "stats":
        stats()
    else:
        main()
