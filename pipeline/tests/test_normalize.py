#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
정규화 유닛 테스트.

    cd pipeline && python tests/test_normalize.py

모든 케이스는 전국 632건 실사에서 실제로 발견된 문구다.
파싱 규칙을 손댈 때마다 여기를 돌려 회귀를 막는다.
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


# ── 오인 위험: 유형은 '가능'인데 안내견 전용 (실측 6건) ──
def test_guide_dog_trap():
    r = normalize(_rec(acmpyTypeCd="전구역 동반가능",
                       acmpyPsblCpam="시각 장애인 안내견",
                       acmpyNeedMtr="목줄 착용"))
    assert r["acmpy_type"] == "all_area"
    assert r["guide_dog_only"] is True, "안내견 전용을 놓치면 오판정이 발생함"


def test_guide_dog_variant():
    """'맹인 안내견' 표기 변형도 잡아야 함 (실측 3건)"""
    assert normalize(_rec(acmpyPsblCpam="맹인 안내견"))["guide_dog_only"] is True
    assert normalize(_rec(acmpyPsblCpam="보조견 동반 입장 가능"))["guide_dog_only"] is True


# ── 전 견종 ──
def test_all_breed():
    r = normalize(_rec(acmpyTypeCd="전구역 동반가능",
                       acmpyPsblCpam="전 견종 동반 가능"))
    assert r["all_breed_ok"] is True
    assert r["size_limit"] is None
    assert r["max_weight_kg"] is None


def test_all_breed_typo():
    """실측 데이터의 오타 '전 견동'"""
    assert normalize(_rec(acmpyPsblCpam="전 견동 동반 가능"))["all_breed_ok"] is True


def test_fierce_excluded():
    r = normalize(_rec(acmpyPsblCpam="맹견 제외 전 견종 동반 가능"))
    assert r["all_breed_ok"] is True
    assert r["fierce_excluded"] is True


# ── 체중 ──
def test_weight_basic():
    assert normalize(_rec(acmpyPsblCpam="9kg 이하 동반 가능"))["max_weight_kg"] == 9.0
    assert normalize(_rec(acmpyPsblCpam="8KG 미만 반려견"))["max_weight_kg"] == 8.0
    assert normalize(_rec(acmpyPsblCpam="15kg미만 반려견"))["max_weight_kg"] == 15.0


def test_weight_with_size():
    r = normalize(_rec(acmpyPsblCpam="중/소형견 10kg 미만만 입실 가능"))
    assert r["max_weight_kg"] == 10.0
    assert r["size_limit"] == "medium", "'중/소형견'을 소형으로만 보면 중형견이 배제됨"


def test_weight_with_vaccine():
    r = normalize(_rec(acmpyPsblCpam="예방접종 완료한 20kg 이하 동반 가능"))
    assert r["max_weight_kg"] == 20.0
    assert "예방접종 증명" in r["required_items"]


def test_weight_over_ban():
    """'15Kg이상 동반 불가' — '이상'이지만 사실상 상한"""
    r = normalize(_rec(acmpyPsblCpam="15Kg이상 동반 불가"))
    assert r["max_weight_kg"] == 15.0


def test_muzzle_threshold_is_not_max():
    """'25kg 이상 입마개 필수'를 상한으로 오인하면 안 됨"""
    r = normalize(_rec(acmpyTypeCd="일부구역 동반가능",
                       etcAcmpyInfo="- 맹견 및 대형견(25kg 이상), 입마개 착용 필수"))
    assert r["max_weight_kg"] is None, "입마개 임계값은 체중 상한이 아님"
    assert r["muzzle_over_kg"] == 25.0


def test_weight_in_etc_only():
    """구역별 예외가 섞인 기타정보의 체중은 확정값으로 쓰지 않음"""
    r = normalize(_rec(
        acmpyTypeCd="일부구역 동반가능",
        acmpyPsblCpam="전 견종 동반 가능",
        etcAcmpyInfo="산림욕장은 전견종 동반 가능하나 캠핑장은 15Kg이상 동반 불가"))
    assert r["max_weight_kg"] is None
    assert r["weight_in_etc_only"] is True
    assert r["confidence"] < 1.0, "불확실한 케이스는 신뢰도가 낮아야 함"


def test_max_count():
    r = normalize(_rec(etcAcmpyInfo="최대 7kg, 최대 2마리까지 가능"))
    assert r["max_count"] == 2


# ── 준비물 ──
def test_need_items_parsing():
    r = normalize(_rec(acmpyNeedMtr="입마개 착용,목줄 착용,이동장(켄넬)사용"))
    assert set(r["required_items"]) == {"입마개", "목줄", "이동장"}


def test_free_use_is_not_an_item():
    """'자유이용'은 준비물이 아니라 제약 없음을 뜻함"""
    r = normalize(_rec(acmpyNeedMtr="자유이용"))
    assert r["free_use"] is True
    assert r["required_items"] == []


def test_etc_token_flags_reference():
    """'기타'는 준비물이 아니라 etcAcmpyInfo 확인 신호"""
    r = normalize(_rec(acmpyNeedMtr="목줄 착용,기타", etcAcmpyInfo="세부 사항 별도 안내"))
    assert r["see_etc_info"] is True
    assert r["required_items"] == ["목줄"]


def test_kennel_from_cpam():
    """가능동물 문구에만 이동장 조건이 있는 경우도 준비물에 반영"""
    r = normalize(_rec(acmpyPsblCpam="이동장(켄넬)에 들어가는 전 견종 동반 가능"))
    assert "이동장" in r["required_items"]


# ── 판정 불가 케이스 ──
def test_explicitly_denied():
    assert normalize(_rec(acmpyPsblCpam="불가"))["explicitly_denied"] is True


def test_needs_inquiry():
    assert normalize(_rec(acmpyPsblCpam="전화문의"))["needs_inquiry"] is True


def test_no_detail():
    r = normalize(_rec())
    assert r["has_detail"] is False
    assert r["confidence"] == 0.0


def test_partial_area_flag():
    """일부구역 + 기타정보 존재 = 원문 확인 유도 (실측 최다 케이스)"""
    r = normalize(_rec(acmpyTypeCd="일부구역 동반가능",
                       acmpyPsblCpam="전 견종 동반 가능",
                       etcAcmpyInfo="카라반 동반 불가(오토캠핑장만 가능)"))
    assert r["zone_detail_in_text"] is True


# ── 근거 보존 ──
def test_source_text_preserved():
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
    print(f"\n{'전부 통과' if not fails else str(fails) + '건 실패'}"
          f" ({sum(1 for k in globals() if k.startswith('test_'))}건)")
    sys.exit(1 if fails else 0)
