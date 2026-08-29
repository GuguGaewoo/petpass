#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
초기 적재 — 번들 에셋(app/assets/places.json)을 Supabase `places` 로 옮긴다.

언제 쓰나:
    Supabase places 테이블을 처음 만든 직후 딱 한 번.
    이후의 갱신은 sync_service.py(증분 동기화)가 담당한다.

왜 필요한가:
    현재 앱은 빌드에 포함된 places.json 을 읽는다. 이걸 DB 로 옮겨야
    앱을 다시 빌드하지 않고도 데이터를 갱신할 수 있다. 이 스크립트는
    그 전환의 출발점으로, 이미 검증된 632건을 그대로 DB 에 넣는다.

    Open API 를 호출하지 않으므로 개발계정 일일 호출 한도를 쓰지 않는다.

실행:
    cd pipeline
    python seed_supabase.py --dry-run   # 먼저 이걸로 검증만
    python seed_supabase.py             # 실제 적재

필요 환경변수 (루트 .env):
    SUPABASE_URL
    SUPABASE_SERVICE_KEY   # service_role / Secret 키. anon·publishable 아님.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# tourapi 를 import 하면 .env 로더가 함께 실행되어
# SUPABASE_URL / SUPABASE_SERVICE_KEY 가 os.environ 에 올라온다.
import tourapi  # noqa: F401
from normalize import normalize

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "app" / "assets" / "places.json"

# 한 번에 upsert 할 행 수.
# PostgREST 요청 본문 크기 제한을 피하고, 실패 시 어느 구간인지 알기 쉽게 한다.
CHUNK_SIZE = 100

NO_KEY_MSG = """
Supabase 서버 키를 찾을 수 없습니다.

  프로젝트 루트 .env 에 아래 두 줄이 필요합니다:
    SUPABASE_URL=https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY=<service_role 또는 Secret 키>

  anon / publishable 키로는 동작하지 않습니다.
  places 테이블은 읽기만 공개이고 쓰기는 service_role 전용이기 때문입니다.
"""


def canonical_template():
    """places 테이블의 전체 컬럼과 기본값을 담은 빈 틀을 만든다.

    왜 이렇게 하나:
        에셋의 각 레코드는 기본값 필드가 생략되어 있어 키 개수가 17~37개로
        제각각이다. 그런데 PostgREST 는 일괄 삽입 시 모든 객체의 키가
        같아야 하고, 다르면 PGRST102 오류로 요청 전체가 실패한다.

        기본값을 여기에 손으로 나열하면 normalize.py 가 바뀔 때 조용히
        어긋나므로, normalize() 를 최소 입력으로 한 번 호출해 그 결과를
        기준 틀로 삼는다. 정규화 로직과 항상 같은 스키마가 보장된다.
    """
    template = normalize({"contentid": "", "title": ""})

    # 이 두 값은 레코드마다 달라야 하므로 틀에서 제외한다.
    template.pop("content_id", None)
    template.pop("title", None)

    # collected_at 은 normalize() 가 '지금'으로 채우지만,
    # seed 는 원본 수집 시각을 보존해야 하므로 에셋 값이 있으면 그것을 쓴다.
    return template


def build_rows(payload):
    """에셋 레코드를 DB 에 넣을 수 있는 균일한 행 목록으로 변환한다."""
    template = canonical_template()
    rows = []

    for record in payload["places"]:
        row = dict(template)      # 기본값으로 채운 틀
        row.update(record)        # 에셋에 실제로 있는 값만 덮어씀

        # 목록에 존재한다는 뜻. 이후 sync_service.py 가 관리한다.
        row["is_active"] = True

        rows.append(row)

    return rows


def validate(rows):
    """적재 전 자체 점검. 문제가 있으면 사유 목록을 돌려준다."""
    problems = []

    if not rows:
        problems.append("행이 하나도 없습니다.")
        return problems

    # 1) 모든 행의 키가 동일한가 (PGRST102 예방)
    key_sets = {frozenset(r.keys()) for r in rows}
    if len(key_sets) != 1:
        problems.append(f"행마다 키 구성이 다릅니다 ({len(key_sets)}종류).")

    # 2) 기본키 누락·중복
    ids = [r.get("content_id") for r in rows]
    if any(not i for i in ids):
        problems.append("content_id 가 비어 있는 행이 있습니다.")
    if len(ids) != len(set(ids)):
        dup = len(ids) - len(set(ids))
        problems.append(f"content_id 가 중복된 행이 {dup}건 있습니다.")

    # 3) not null 컬럼에 None 이 들어가지 않는가
    not_null = ["title", "overview", "homepage", "source_text", "confidence"]
    for col in not_null:
        bad = sum(1 for r in rows if r.get(col) is None)
        if bad:
            problems.append(f"{col} 이 null 인 행이 {bad}건 있습니다.")

    return problems


def summarize(rows):
    """적재될 내용을 사람이 확인할 수 있게 요약한다."""
    total = len(rows)
    filled = lambda f: sum(1 for r in rows if f(r))  # noqa: E731

    print(f"  전체            {total}건")
    print(f"  좌표 있음        {filled(lambda r: r.get('lat') is not None)}건")
    print(f"  상세정보 있음    {filled(lambda r: r.get('has_detail'))}건")
    print(f"  개요 있음        {filled(lambda r: r.get('overview'))}건")
    print(f"  체중제한 있음    {filled(lambda r: r.get('max_weight_kg') is not None)}건")
    print(f"  안내견 전용      {filled(lambda r: r.get('guide_dog_only'))}건")
    print(f"  동반 명시 불가   {filled(lambda r: r.get('explicitly_denied'))}건")
    print(f"  컬럼 수         {len(rows[0])}개")


def load_asset():
    if not ASSET.exists():
        print(f"에셋을 찾을 수 없습니다: {ASSET}")
        sys.exit(1)

    with open(ASSET, encoding="utf-8") as f:
        payload = json.load(f)

    declared = payload.get("count")
    actual = len(payload.get("places", []))
    if declared != actual:
        print(f"경고: count({declared}) 와 실제 건수({actual}) 가 다릅니다.")

    return payload


def upload(rows):
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_SERVICE_KEY", "")

    if not url or not key:
        print(NO_KEY_MSG)
        sys.exit(1)

    # 지연 import: --dry-run 은 supabase 패키지 없이도 돌아가게 한다.
    from supabase import create_client

    db = create_client(url, key)

    total = len(rows)
    done = 0

    for start in range(0, total, CHUNK_SIZE):
        chunk = rows[start : start + CHUNK_SIZE]

        db.table("places").upsert(chunk, on_conflict="content_id").execute()

        done += len(chunk)
        print(f"  {done}/{total} 업로드")

    return done


def main():
    parser = argparse.ArgumentParser(
        description="번들 에셋을 Supabase places 로 초기 적재한다."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="DB 에 쓰지 않고 검증과 요약만 출력한다.",
    )
    args = parser.parse_args()

    print("── 에셋 읽기 ──")
    payload = load_asset()
    print(f"  {ASSET.relative_to(ROOT)}")
    print(f"  출처: {payload.get('source', '(없음)')}")

    print("\n── 행 변환 ──")
    rows = build_rows(payload)
    summarize(rows)

    print("\n── 검증 ──")
    problems = validate(rows)
    if problems:
        for p in problems:
            print(f"  ✗ {p}")
        print("\n문제가 있어 중단합니다.")
        sys.exit(1)
    print("  ✓ 키 구성 균일 / content_id 유효 / not-null 충족")

    if args.dry_run:
        print("\n--dry-run 이므로 여기서 종료합니다. DB 는 변경되지 않았습니다.")
        return

    print("\n── Supabase 적재 ──")
    done = upload(rows)

    print(f"\n완료: {done}건 → places")
    print("\n확인용 SQL:")
    print("  select count(*) from places where is_active;")


if __name__ == "__main__":
    main()
