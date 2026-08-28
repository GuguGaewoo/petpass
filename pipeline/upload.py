#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
적재 — 정규화 결과(pet_normalized.json)를 Supabase `places` 테이블에 upsert.

sync.py 의 마지막 단계(`python sync.py upload` 또는 `python sync.py`)에서
호출된다. 단독 실행도 가능하다:

    python upload.py

필요 환경변수 (.env 또는 실제 환경변수):
    SUPABASE_URL
    SUPABASE_SERVICE_KEY   ← anon 키가 아니라 반드시 service_role 키.
                              RLS 정책상 anon 키로는 쓰기가 막혀 있다.

이 스크립트는 서버/배치 전용이며 Flutter 앱에는 절대 포함되지 않는다.
"""

import os
import sys

# tourapi 를 import 하면 .env 로더가 함께 실행되어
# SUPABASE_URL / SUPABASE_SERVICE_KEY 도 os.environ 에 올라온다.
import tourapi
from tourapi import NORMALIZED_FILE, load_json

# 한 번에 upsert 할 행 수.
# Supabase(PostgREST)는 요청 본문 크기 제한이 있어, 632건 전체를
# 한 번에 보내는 것보다 나눠 보내는 편이 안전하고 실패 시 원인 파악도 쉽다.
CHUNK_SIZE = 100

NO_KEY_MSG = """
Supabase 서버 키를 찾을 수 없습니다.

  pipeline/.env 에 아래 두 줄을 추가하세요:
    SUPABASE_URL=https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY=service_role 키 (anon 키 아님)

  service_role 키는 Supabase 대시보드 → Project Settings → API 에서
  확인할 수 있습니다. 이 키는 절대 앱(app/)이나 커밋에 넣지 마세요.
"""


def _client():
    """환경변수를 검사하고 Supabase 클라이언트를 만든다."""
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_SERVICE_KEY", "")

    if not url or not key:
        print(NO_KEY_MSG)
        sys.exit(1)

    # 지연 import: upload.py 를 쓰지 않는 스크립트(normalize 단독 실행 등)는
    # supabase 패키지가 없어도 동작하게 하기 위함.
    from supabase import create_client

    return create_client(url, key)


def _rows():
    """정규화 결과를 읽어 Supabase 컬럼명에 맞춘 행 목록으로 변환한다."""
    rows = load_json(NORMALIZED_FILE, [])
    if not rows:
        print(
            f"{os.path.basename(NORMALIZED_FILE)} 가 비어 있습니다. "
            "python normalize.py 를 먼저 실행하세요."
        )
        return []

    # normalize.py 출력은 이미 Supabase 컬럼명과 동일한 snake_case 이므로
    # 별도 매핑이 필요 없다. 다만 목록에 실제로 존재한다는 뜻으로
    # is_active 만 명시적으로 켠다. (사라진 장소의 비활성화는
    # sync_service.py 의 증분 동기화가 담당한다.)
    for row in rows:
        row["is_active"] = True

    return rows


def main():
    rows = _rows()
    if not rows:
        return

    db = _client()
    total = len(rows)
    uploaded = 0

    for start in range(0, total, CHUNK_SIZE):
        chunk = rows[start : start + CHUNK_SIZE]

        db.table("places").upsert(
            chunk,
            on_conflict="content_id",
        ).execute()

        uploaded += len(chunk)
        print(f"  {uploaded}/{total} 업로드")

    print(f"\n적재 완료: {uploaded}건 → Supabase places")


if __name__ == "__main__":
    main()
