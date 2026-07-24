#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
정규화 유닛 테스트.

    cd pipeline && python -m pytest tests/ -v
    (pytest 없으면: python tests/test_normalize.py)

파싱 규칙을 추가할 때마다 여기에 케이스를 같이 추가하세요.
실제 데이터에서 발견한 특이 문구를 발견 즉시 넣어두면 회귀를 막을 수 있습니다.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from normalize import normalize


def _rec(**kw):
    base = {"contentid": "1", "title": "테스트", "contenttypeid": "32",
            "mapx": "127.0", "mapy": "37.5", "modifiedtime": "20241218152408"}
    base.update(kw)
    return base


def test_guide_dog_trap():
    """실제 수집 사례: 유형은 '전구역 동반가능'인데 안내견만 가능한 곳.
       서비스의 존재 이유가 되는 케이스이므로 절대 깨지면 안 됨."""
    r = normalize(_rec(acmpyTypeCd="전구역 동반가능",
                       acmpyPsblCpam="시각 장애인 안내견",
                       acmpyNeedMtr="목줄 착용"))
    assert r["acmpy_type"] == "all_area"
    assert r["guide_dog_only"] is True, "안내견 전용을 놓치면 오판정이 발생함"
    assert "목줄" in r["required_items"]


def test_weight_limit():
    r = normalize(_rec(acmpyTypeCd="일부구역 동반가능",
                       acmpyPsblCpam="10kg 이하 소형견",
                       acmpyNeedMtr="목줄, 배변봉투 지참"))
    assert r["max_weight_kg"] == 10.0
    assert r["size_restriction"] == "small"
    assert r["guide_dog_only"] is False
    assert set(["목줄", "배변봉투"]).issubset(set(r["required_items"]))


def test_no_detail():
    """상세정보가 아예 없는 곳 — '정보없음'으로 정직하게 표시해야 함"""
    r = normalize(_rec())
    assert r["has_detail"] is False
    assert r["acmpy_type"] is None
    assert r["confidence"] == 0.0


def test_source_text_preserved():
    """판정 근거 원문은 절대 손실되면 안 됨"""
    r = normalize(_rec(acmpyPsblCpam="시각 장애인 안내견"))
    assert r["source_text"]["acmpyPsblCpam"] == "시각 장애인 안내견"
    assert r["last_modified"].startswith("2024-12-18")


if __name__ == "__main__":
    fails = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print(f"  PASS  {name}")
            except AssertionError as e:
                fails += 1
                print(f"  FAIL  {name}: {e}")
    print("\n전부 통과" if not fails else f"\n{fails}건 실패")
    sys.exit(1 if fails else 0)
