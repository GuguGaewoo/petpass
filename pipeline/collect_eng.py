#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
영문 관광정보 수집 — F-09 다국어 표기용.

영문 서비스는 각국 선호 관광지 중심으로만 번역이 제공되어 커버리지가 낮다.
없는 곳이 다수일 것을 전제로, 앱에서는 국문 폴백을 기본 동작으로 둔다.

실행:
    python collect_eng.py
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tourapi import (
    DATA_DIR, ENG_BASE, SLEEP, call, cid_of, load_json,
    merged_records, require_key, save_json,
)

ENG_FILE = os.path.join(DATA_DIR, "eng_detail.json")
ENG_OP_COMMON = "detailCommon2"


def main():
    require_key()
    base = merged_records()
    if not base:
        print("수집 데이터가 없습니다.")
        return

    done = load_json(ENG_FILE, {})
    todo = [cid_of(r) for r in base if cid_of(r) and cid_of(r) not in done]
    print("수집 대상 {}건 (기존 {}건 완료)\n".format(len(todo), len(done)))

    fails, streak = 0, 0
    try:
        for i, cid in enumerate(todo, 1):
            try:
                items, _ = call(ENG_BASE, ENG_OP_COMMON, contentId=cid)
                # 결과 없음 = 영문 번역이 없는 곳. None 으로 기록해 재시도를 막는다.
                done[cid] = items[0] if items else None
                streak = 0
            except Exception as e:
                fails += 1
                streak += 1
                print("  {} 실패: {}".format(cid, str(e)[:60]))
                if streak >= 10:
                    print("\n[중단] 연속 10회 실패")
                    break
            if i % 100 == 0:
                save_json(ENG_FILE, done)
                print("  {}/{} ... 저장".format(i, len(todo)))
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 - 여기까지 저장합니다.")

    save_json(ENG_FILE, done)
    have = sum(1 for v in done.values() if v)
    n = len(done)
    print("\n영문 {}건 -> {}  (실패 {}건)".format(n, os.path.basename(ENG_FILE), fails))
    print("\n-- 커버리지 --")
    print("  영문 정보 있음   {:>4}건  ({:.0f}%)".format(have, have / max(n, 1) * 100))
    print("  없음             {:>4}건".format(n - have))

    # 실제로 쓸 수 있는 필드가 채워져 있는지
    for k, label in [("title", "영문 상호명"), ("addr1", "영문 주소"), ("overview", "영문 개요")]:
        c = sum(1 for v in done.values() if v and (v.get(k) or "").strip())
        print("  {:12} {:>4}건".format(label, c))


if __name__ == "__main__":
    main()
