#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Supabase 적재.

⚠ 아직 뼈대입니다. Supabase 프로젝트를 만든 뒤 db/schema.sql 을 적용하고
   pipeline/.env 에 SUPABASE_URL, SUPABASE_SERVICE_KEY 를 채우세요.

service_role 키는 RLS 를 우회하므로 이 배치에서만 쓰고 절대 앱에 넣지 마세요.
앱은 anon 키 + RLS 읽기 정책으로만 접근합니다.
"""

import os

from tourapi import NORMALIZED_FILE, load_json

BATCH = 500


def main():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY")
    if not (url and key):
        print("SUPABASE_URL / SUPABASE_SERVICE_KEY 가 .env 에 없습니다. 적재를 건너뜁니다.")
        return

    rows = load_json(NORMALIZED_FILE, [])
    if not rows:
        print("정규화 데이터가 없습니다. normalize.py 를 먼저 실행하세요.")
        return

    from supabase import create_client
    sb = create_client(url, key)

    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        sb.table("places").upsert(chunk, on_conflict="content_id").execute()
        print(f"  {min(i + BATCH, len(rows))}/{len(rows)} 적재")

    print(f"적재 완료 {len(rows)}건")


if __name__ == "__main__":
    main()
