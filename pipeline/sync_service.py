#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
운영 동기화 — Supabase `places` 를 KTO Open API 최신 상태로 맞춘다.

sync.py 와의 차이:
    sync.py 는 로컬 파일(pipeline/data/*.json)에 이어서 수집하는
    "1회성 전체 수집" 스크립트다. GitHub Actions 처럼 매번 새 컨테이너에서
    시작하는 환경(로컬 파일이 없음)에서는 맞지 않는다.

    sync_service.py 는 Supabase 자체를 상태 저장소로 쓴다.
        1. areaBasedList2 로 전국 목록을 다시 받는다 (가벼움)
        2. 각 항목의 modifiedtime 을 DB의 last_modified 와 비교한다
        3. 값이 같으면 상세 API를 부르지 않고 목록 수준 필드만 갱신한다
        4. 값이 다르거나 신규면 detailPetTour2 를 불러 반려동물 동반
           조건까지 다시 정규화한다
        5. 이번 목록에 없는(사라진) 장소는 삭제하지 않고 is_active=false
           로만 표시한다 (reports FK, 과거 이력 보존)

    즉 632건이라도 상세 API는 "실제로 바뀐 곳"만 호출하므로 개발키
    일일 호출 한도(보통 1,000건)로도 매일 운영할 수 있다.

실행:
    python sync_service.py

필요 환경변수:
    TOUR_API_KEY
    SUPABASE_URL
    SUPABASE_SERVICE_KEY
"""

import os
import sys
import time
from datetime import datetime

# .env 로더 부작용 + 공통 상수/함수
import tourapi
from normalize import CONTENT_TYPE, normalize
from tourapi import AREA_CODES, ARRANGE, PET_BASE, PET_OP_AREA, PET_OP_DETAIL, SLEEP, call, cid_of

# 한 번의 Supabase 응답으로 가져올 최대 행 수.
# 전체 places 를 페이지네이션으로 끝까지 읽기 위한 페이지 크기다.
PAGE_SIZE = 1000


def _iso(raw):
    """TourAPI 의 'YYYYMMDDHHMMSS' 형태를 ISO 8601 문자열로. 실패하면 None."""
    s = str(raw or "").strip()
    if len(s) < 8:
        return None
    try:
        return datetime.strptime(s[:14].ljust(14, "0"), "%Y%m%d%H%M%S").isoformat()
    except ValueError:
        return None


def _same_time(a, b):
    """Supabase timestamptz 는 '+00:00' 등 표기가 붙을 수 있어 초 단위까지만 비교."""
    return str(a or "")[:19] == str(b or "")[:19]


def _client():
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_SERVICE_KEY", "")
    if not url or not key:
        print(
            "SUPABASE_URL / SUPABASE_SERVICE_KEY 가 없습니다. "
            "pipeline/.env 또는 Actions Secrets 를 확인하세요."
        )
        sys.exit(1)

    from supabase import create_client

    return create_client(url, key)


class ApiLogger:
    """KTO Open API 호출을 kto_api_log 에 남긴다.

    로그 실패(테이블 없음, 네트워크 문제 등)가 동기화 자체를 막으면
    안 되므로 예외를 삼킨다 — 로깅은 부가 기능이다.
    """

    def __init__(self, db, caller):
        self._db = db
        self._caller = caller

    def call(self, base, op, *, cid=None, **params):
        try:
            result = call(base, op, **params)
            self._log(op, cid=cid, ok=True)
            return result
        except Exception as e:
            self._log(op, cid=cid, ok=False, error=str(e)[:300])
            raise

    def _log(self, endpoint, *, cid=None, ok=True, error=None):
        try:
            self._db.table("kto_api_log").insert(
                {
                    "endpoint": endpoint,
                    "content_id": cid,
                    "caller": self._caller,
                    "success": ok,
                    "error_message": error,
                }
            ).execute()
        except Exception:
            pass


def _fetch_current_places(db):
    """Supabase 의 전체 places 를 content_id 기준 딕셔너리로 가져온다."""
    current = {}
    start = 0
    while True:
        rows = (
            db.table("places")
            .select("*")
            .range(start, start + PAGE_SIZE - 1)
            .execute()
            .data
        )
        for row in rows:
            current[str(row["content_id"])] = row
        if len(rows) < PAGE_SIZE:
            break
        start += PAGE_SIZE
    return current


def _fetch_live_list(logger):
    """전국 areaBasedList2 목록을 content_id 기준 딕셔너리로 가져온다."""
    live = {}
    for area in AREA_CODES:
        page = 1
        while True:
            params = {"numOfRows": 100, "pageNo": page, "areaCode": area}
            if ARRANGE:
                params["arrange"] = ARRANGE

            items, total = logger.call(PET_BASE, PET_OP_AREA, **params)

            for item in items:
                cid = cid_of(item)
                if cid:
                    live[cid] = item

            if not items or page * 100 >= total:
                break
            page += 1
            time.sleep(SLEEP)

    return live


def _list_level_patch(item, old):
    """상세 API 없이도 갱신 가능한 목록 수준 필드만 뽑는다."""
    return {
        "title": item.get("title") or old.get("title", ""),
        "address": " ".join(
            x for x in [item.get("addr1"), item.get("addr2")] if x
        ).strip(),
        "content_type": CONTENT_TYPE.get(str(item.get("contenttypeid")), "기타"),
        "content_type_id": str(item.get("contenttypeid") or ""),
        "area_code": str(item.get("areacode") or ""),
        "sigungu_code": str(item.get("sigungucode") or ""),
        "lat": float(item["mapy"]) if item.get("mapy") else None,
        "lng": float(item["mapx"]) if item.get("mapx") else None,
        "tel": item.get("tel") or old.get("tel", ""),
        "image": item.get("firstimage") or old.get("image", ""),
        "is_active": True,
    }


def _refresh_detail(item, old, logger):
    """상세 API를 불러 반려동물 동반 조건까지 다시 정규화한다."""
    cid = cid_of(item)
    detail, _ = logger.call(PET_BASE, PET_OP_DETAIL, cid=cid, contentId=cid)

    rec = dict(item)
    if detail:
        rec.update(detail[0])

    # 개요/홈페이지/대표이미지는 별도 국문 상세 API 몫이라 이 흐름에서는
    # 얻을 수 없다. 기존 DB 값을 그대로 보존해 정보 손실을 막는다.
    kor = {}
    if old is not None:
        kor = {
            "overview": old.get("overview", ""),
            "homepage": old.get("homepage", ""),
            "firstimage": old.get("image", ""),
        }

    row = normalize(rec, kor_detail=kor)
    row["is_active"] = True
    return row


def main():
    db = _client()
    logger = ApiLogger(db, caller="batch")

    print("── 현재 Supabase 상태 조회 ──")
    current = _fetch_current_places(db)
    print(f"  기존 {len(current)}건")

    print("\n── KTO 최신 목록 조회 ──")
    live = _fetch_live_list(logger)
    print(f"  최신 {len(live)}건")

    print("\n── 변경분 반영 ──")
    changed_detail = 0
    changed_list_only = 0

    for cid, item in live.items():
        old = current.get(cid)
        kto_modified = _iso(item.get("modifiedtime"))

        if old is not None and _same_time(old.get("last_modified"), kto_modified):
            # 반려동물 동반 조건은 그대로다. 목록 수준 기본정보만 최신화.
            patch = _list_level_patch(item, old)
            db.table("places").update(patch).eq("content_id", cid).execute()
            changed_list_only += 1
            continue

        # 신규 장소 또는 modifiedtime 이 바뀐 장소만 상세 API 호출
        row = _refresh_detail(item, old, logger)
        db.table("places").upsert(row, on_conflict="content_id").execute()
        changed_detail += 1
        time.sleep(SLEEP)

    # 이번 목록에서 사라진 장소는 삭제하지 않고 비활성화만 한다.
    missing = sorted(set(current) - set(live))
    if missing:
        db.table("places").update({"is_active": False}).in_(
            "content_id", missing
        ).execute()

    print(
        f"\n완료: 목록기준 갱신 {changed_list_only}건 / "
        f"상세 재조회 {changed_detail}건 / "
        f"비활성화 {len(missing)}건"
    )


if __name__ == "__main__":
    main()
