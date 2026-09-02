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
    """일부구역인데 유형도 특정 못 하면 원문 확인 유도 (실측 최다 케이스)

    유형이 특정되면 플래그를 끄고 그 유형을 직접 안내한다.
    "원문을 확인하세요" 보다 "숙박시설은 불가" 가 나은 안내이기 때문이다.
    """
    # 유형 특정 가능 → 플래그 대신 banned_zones 로 안내
    r = normalize(_rec(acmpyTypeCd="일부구역 동반가능",
                       acmpyPsblCpam="전 견종 동반 가능",
                       etcAcmpyInfo="카라반 동반 불가(오토캠핑장만 가능)"))
    assert r["banned_zones"] == ["숙박"]
    assert r["zone_detail_in_text"] is False

    # 고유명사 구역이라 유형을 알 수 없음 → 원문 확인 유도 유지
    r2 = normalize(_rec(acmpyTypeCd="일부구역 동반가능",
                        acmpyPsblCpam="전 견종 동반 가능",
                        etcAcmpyInfo="청운답원은 동반 불가"))
    assert r2["banned_zones"] == []
    assert r2["zone_detail_in_text"] is True


# ── 근거 보존 ──
def test_source_text_preserved():
    r = normalize(_rec(acmpyPsblCpam="시각 장애인 안내견"))
    assert r["source_text"]["acmpyPsblCpam"] == "시각 장애인 안내견"
    assert r["last_modified"].startswith("2024-12-18")


# ── 실시간 조회 경로: kor_detail 인자 (backend/main.py 가 사용) ──
def test_kor_detail_default_uses_local_file():
    # 인자를 안 넘기면 기존과 동일하게 kor_detail.json(_KOR)에서 찾는다.
    # 테스트 데이터에는 없는 contentId 이므로 빈 값이어야 한다.
    r = normalize(_rec(contentid="존재하지-않는-id"))
    assert r["overview"] == ""
    assert r["homepage"] == ""


def test_kor_detail_override_takes_priority():
    # 실시간 상세조회는 방금 받아온 국문 상세를 즉시 넘긴다.
    # _KOR(로컬 파일) 값이 있더라도 kor_detail 인자가 우선해야 한다.
    r = normalize(
        _rec(contentid="1"),
        kor_detail={
            "overview": "실시간으로 받은 개요",
            "homepage": '<a href="https://example.com">홈페이지</a>',
            "firstimage": "https://example.com/live.jpg",
        },
    )
    assert r["overview"] == "실시간으로 받은 개요"
    assert r["homepage"] == "https://example.com"
    assert r["image"] == "https://example.com/live.jpg"


def test_kor_detail_none_falls_back_to_local_file():
    # kor_detail=None 은 "값을 못 받았다"는 뜻이 아니라
    # "이 호출부는 로컬 파일 기준으로 처리해 달라"는 기존 동작이다.
    r = normalize(_rec(contentid="1"), kor_detail=None)
    assert r["overview"] == ""


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


# ══════════════════════════════════════════════════
# 동반 불가 구역 분류
# 모든 케이스는 실측 75개 문장에서 가져왔다.
# ══════════════════════════════════════════════════
import rules.patterns as _P


def test_zone_basic_indoor():
    assert _P.extract_banned_zones("- 실내는 동반 불가") == ["실내"]
    assert _P.extract_banned_zones("- 내부 시설 동반 불가") == ["실내"]
    assert _P.extract_banned_zones("- 가옥 안쪽은 동반 불가") == ["실내"]


def test_zone_multiple_kinds():
    # "철도박물관 및 카페는 동반 불가" — 나열을 각각 분류한다
    assert set(_P.extract_banned_zones("- 철도박물관 및 카페는 동반 불가")) == {
        "전시", "식음료"
    }
    assert set(_P.extract_banned_zones("- 마트와 식당은 출입 불가")) == {"식음료"}
    assert set(_P.extract_banned_zones("- 식당, 카페, 일부매장 동반 불가")) == {"식음료"}


def test_zone_ignores_subject_not_place():
    # 견종·동반자 제한은 구역이 아니다. fierce_excluded 등이 따로 처리한다.
    assert _P.extract_banned_zones("- 맹견 동반 불가") == []
    assert _P.extract_banned_zones("- 5대맹견 및 하이브리드 반려견 동반 불가") == []
    assert _P.extract_banned_zones("- 미리 논의 되지 않은 반려견 동반 불가") == []


def test_zone_ignores_condition_not_place():
    # 조건문을 구역으로 뽑으면 엉뚱한 안내가 된다.
    assert _P.extract_banned_zones("- 필수예방접종 미완료 시 동반 불가") == []
    assert _P.extract_banned_zones("- 반려동물의 몸이 외부에 노출되면 동반 불가") == []
    assert _P.extract_banned_zones("- 우천 시에는 동반 불가") == []


def test_zone_partial_allow_sentence():
    # 앞부분의 '가능'에 속지 않고 뒤의 금지 대상을 잡아야 한다.
    assert _P.extract_banned_zones(
        "- 공터는 동반 가능하나 카페 내부는 동반 불가"
    ) == ["실내"]
    assert _P.extract_banned_zones(
        "- 산림욕장은 전견종 동반 가능하나 캠핑장은 15Kg이상 동반 불가"
    ) == ["체육"]


def test_zone_unknown_is_skipped_not_guessed():
    # 고유명사 구역은 유형을 알 수 없다. 추측하지 않고 건너뛴다.
    # (원문은 화면에 그대로 표시되므로 정보가 사라지지는 않는다)
    assert _P.extract_banned_zones("- 청운답원은 동반 불가") == []
    assert _P.extract_banned_zones("- 스페이스 워크 동반 불가") == []


def test_zone_no_ban_sentence():
    assert _P.extract_banned_zones("- 목줄 착용 필수") == []
    assert _P.extract_banned_zones("") == []
    assert _P.extract_banned_zones(None) == []


def test_zone_dedupes():
    # 여러 줄에서 같은 유형이 나와도 한 번만
    text = "- 실내는 동반 불가\n- 내부 시설 동반 불가"
    assert _P.extract_banned_zones(text) == ["실내"]


# ══════════════════════════════════════════════════
# 안내견 전용 — 기타정보에 있는 경우
# ══════════════════════════════════════════════════
def test_guide_dog_only_from_etc():
    """가능동물이 비어 있고 기타정보에만 전용 표현이 있는 경우.

    실측: 힐튼 가든 인 서울 강남 — '장애우 안내견만 이용가능'
    이 케이스가 유실되어 '조건부 가능'으로 표시되고 있었다.
    """
    r = normalize(_rec(acmpyPsblCpam="", etcAcmpyInfo="장애우 안내견만 이용가능"))
    assert r["guide_dog_only"] is True


def test_guide_dog_exception_is_not_only():
    """'안내견 제외 ~' 은 정반대 의미다. 일반견도 갈 수 있다.

    이걸 전용으로 잡으면 갈 수 있는 곳이 불가로 뒤집힌다.
    실측: 동대문디자인플라자, 동대문역사문화공원
    """
    r = normalize(_rec(
        acmpyPsblCpam="전 견종 동반 가능",
        etcAcmpyInfo="- 안내견 제외 이동장 또는 이동가방으로만 실내 동반 가능"))
    assert r["guide_dog_only"] is False


def test_guide_dog_only_zone_scoped_is_not_whole_place():
    """특정 구역만 안내견 전용인 경우 장소 전체를 불가로 보지 않는다.

    실측: 고성 DMZ박물관 — '전시실 내에는 안내견 이외 동반 금지'
    일부구역 동반가능 + 전 견종 동반 가능인 곳이라, 전체를 전용으로
    잡으면 야외를 갈 수 있는 곳이 통째로 막힌다.
    """
    r = normalize(_rec(acmpyTypeCd="일부구역 동반가능",
                       acmpyPsblCpam="전 견종 동반 가능",
                       etcAcmpyInfo="- 전시실 내에는 안내견 이외 동반 금지"))
    assert r["guide_dog_only"] is False


def test_guide_dog_only_exclusive_phrasing():
    """구역 한정이 없는 '안내견 이외 출입 금지' 는 전용이다."""
    r = normalize(_rec(acmpyPsblCpam="",
                       etcAcmpyInfo="안내견 이외 출입 금지"))
    assert r["guide_dog_only"] is True


def test_guide_dog_mention_is_not_only():
    """단순 언급은 전용이 아니다."""
    r = normalize(_rec(acmpyPsblCpam="",
                       etcAcmpyInfo="보조견 동반 가능, 공원 내 기차전시관 안전요원 상주"))
    assert r["guide_dog_only"] is False
