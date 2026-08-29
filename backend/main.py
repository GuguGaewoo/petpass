#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PetPass Backend — 장소 상세화면 진입 시 실제 KTO Open API를 재조회한다.

역할 분리:
    앱 시작 시 전체 목록      → Supabase places (pipeline/sync_service.py 가 매일 갱신)
    사용자가 장소 상세 클릭   → 이 서버가 detailPetTour2 를 즉시 재호출  ← 지금 이 파일

반려동물 동반 조건이 실제로 검증되어야 하는 지점이 "상세 클릭 시점"이므로
매번 클릭마다 무거운 국문 관광정보(detailCommon2)까지 다시 부르지 않고,
반려동물 동반 조건 API 한 번만 호출한다. 개요/홈페이지/대표이미지는
Supabase에 이미 있는 값을 그대로 유지한다.

TOUR_API_KEY 와 SUPABASE_SERVICE_KEY 는 이 서버(환경변수)에만 있고
Flutter 앱 빌드에는 절대 들어가지 않는다.

로컬 실행:
    pip install -r backend/requirements.txt
    uvicorn backend.main:app --reload --port 8000
"""

import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# pipeline/ 모듈(tourapi, normalize)을 그대로 재사용한다.
# 판정 규칙이 배치와 실시간, 두 군데로 갈라지지 않게 하기 위함이다.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "pipeline"))

import tourapi  # noqa: E402  (.env 로더 부작용으로 TOUR_API_KEY 등을 올린다)
from normalize import normalize  # noqa: E402
from tourapi import PET_BASE, PET_OP_DETAIL, call  # noqa: E402

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError(
        "SUPABASE_URL / SUPABASE_SERVICE_KEY 환경변수가 없습니다. "
        "backend 실행 환경(로컬 .env 또는 배포 서버 환경변수)을 확인하세요."
    )

from supabase import create_client  # noqa: E402

db = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

app = FastAPI(title="PetPass Backend")

# Flutter Web 이 호출할 수 있도록 허용 출처를 연다.
# 콤마로 여러 개 지정 가능. 운영 도메인만 넣고, 개발 중에만 localhost 를 추가한다.
_origins = [
    x.strip()
    for x in os.getenv("ALLOWED_ORIGINS", "http://localhost:8080").split(",")
    if x.strip()
]

# 같은 장소를 이 시간 안에 다시 조회하면 KTO API 를 재호출하지 않고
# 직전 확인 결과(DB 캐시)를 그대로 돌려준다.
#
# 개발계정은 일 1,000건 제한이 있다. 심사위원 여러 명이 같은 장소를
# 오가며 눌러보면 그 한도를 금방 소진할 수 있는데, 몇 분 사이에 관광
# 데이터가 바뀔 일은 사실상 없으므로 재호출의 실익이 없다.
#
# 환경변수 LIVE_TTL_SECONDS 로 조정 가능. 0 이면 항상 재호출한다.
try:
    LIVE_TTL_SECONDS = int(os.getenv("LIVE_TTL_SECONDS", "600"))
except ValueError:
    LIVE_TTL_SECONDS = 600

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)


def _log(endpoint: str, *, cid: str | None = None, ok: bool = True, error: str | None = None) -> None:
    """KTO API 호출 기록. 실패해도 요청 자체는 계속 진행한다 — 로깅은 부가 기능."""
    try:
        db.table("kto_api_log").insert(
            {
                "endpoint": endpoint,
                "content_id": cid,
                "caller": "live",
                "success": ok,
                "error_message": error,
            }
        ).execute()
    except Exception:
        pass


@app.get("/health")
def health():
    return {"ok": True}


def _is_fresh(row: dict) -> bool:
    """직전 실시간 확인이 TTL 안에 있으면 True.

    live_checked_at 이 없으면(배치로만 들어온 장소) 항상 False 를 반환해
    최초 1회는 반드시 실제 API 를 호출하도록 한다.
    """
    if LIVE_TTL_SECONDS <= 0:
        return False

    raw = row.get("live_checked_at")
    if not raw:
        return False

    try:
        # Supabase 는 '+00:00' 또는 'Z' 로 끝나는 ISO 문자열을 준다.
        checked = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except ValueError:
        return False

    # 타임존 정보가 없으면 UTC 로 간주한다.
    if checked.tzinfo is None:
        checked = checked.replace(tzinfo=timezone.utc)

    age = (datetime.now(timezone.utc) - checked).total_seconds()
    return 0 <= age < LIVE_TTL_SECONDS


@app.get("/api/places/{content_id}/latest")
def latest_place(content_id: str):
    """장소 하나의 반려동물 동반 조건을 실제 KTO API로 다시 확인해 반환한다."""

    rows = (
        db.table("places")
        .select("*")
        .eq("content_id", content_id)
        .limit(1)
        .execute()
        .data
    )

    if not rows:
        raise HTTPException(status_code=404, detail="place not found")

    old = rows[0]

    # TTL 안이면 KTO 를 다시 부르지 않고 직전 확인 결과를 그대로 준다.
    # 호출량을 아끼기 위한 것이며, 사용자에게 보이는 내용은 동일하다.
    if _is_fresh(old):
        return old

    try:
        detail, _ = call(PET_BASE, PET_OP_DETAIL, contentId=content_id)
        _log(PET_OP_DETAIL, cid=content_id, ok=True)
    except Exception as e:
        _log(PET_OP_DETAIL, cid=content_id, ok=False, error=str(e)[:300])
        # 여기서 500을 던지지 않고 502로 명확히 구분한다 —
        # Flutter 쪽 PlaceRepository.loadLatest() 가 이 실패를 보고
        # 기존(캐시된) 장소 데이터로 조용히 폴백한다.
        raise HTTPException(status_code=502, detail="tour api unavailable")

    # Supabase 에 저장된 기존 값을 TourAPI 원본 필드 이름으로 재조립한다.
    # normalize() 는 원본(raw) 필드명을 기대하기 때문이다.
    rec = {
        "contentid": old["content_id"],
        "title": old.get("title", ""),
        "addr1": old.get("address", ""),
        "contenttypeid": old.get("content_type_id", ""),
        "areacode": old.get("area_code", ""),
        "sigungucode": old.get("sigungu_code", ""),
        "mapy": old.get("lat"),
        "mapx": old.get("lng"),
        "tel": old.get("tel", ""),
        "firstimage": old.get("image", ""),
    }
    if detail:
        rec.update(detail[0])

    # 개요/홈페이지/대표이미지는 국문 관광정보 API 몫이라 이 호출로는
    # 얻을 수 없다. 기존 DB 값을 그대로 보존한다.
    kor = {
        "overview": old.get("overview", ""),
        "homepage": old.get("homepage", ""),
        "firstimage": old.get("image", ""),
    }

    fresh = normalize(rec, kor_detail=kor)

    # detailPetTour2 응답에 modifiedtime 이 없는 경우가 있다.
    # 이 경우 최종수정일을 지우지 않고 기존 값을 유지한다.
    if not fresh.get("last_modified"):
        fresh["last_modified"] = old.get("last_modified")

    fresh["is_active"] = True
    fresh["live_checked_at"] = datetime.now(timezone.utc).isoformat()

    # collected_at 은 '이 장소를 처음 수집한 시각'이다.
    # normalize() 는 배치 수집을 전제로 매번 현재 시각을 채우므로,
    # 실시간 조회에서 그대로 두면 클릭할 때마다 최초 수집 시각이
    # 사라진다. 기존 값이 있으면 보존한다.
    # (마지막으로 실제 확인한 시각은 live_checked_at 이 담당한다.)
    if old.get("collected_at"):
        fresh["collected_at"] = old["collected_at"]

    # 이번에 확인한 최신값을 캐시(Supabase)에도 반영해 둔다.
    # 다음 사용자가 같은 장소를 열 때 목록 화면에도 최신값이 보이게 하기 위함.
    try:
        db.table("places").upsert(fresh, on_conflict="content_id").execute()
    except Exception:
        # 캐시 갱신 실패는 이번 응답에 영향을 주지 않는다.
        pass

    return fresh
