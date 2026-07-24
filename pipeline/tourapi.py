#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TourAPI 호출 공통 모듈.

tour_probe.py(진단), sync.py(운영) 양쪽이 이 모듈을 씁니다.
공공데이터포털 특유의 함정들이 여기 모여 있으니 직접 requests 를 쓰지 마세요.
  - 0건일 때 items 가 빈 딕셔너리가 아니라 빈 문자열 "" 로 옴
  - 에러도 HTTP 200 + XML/HTML 로 오는 경우가 많음
  - 인증키가 Encoding/Decoding 두 종류인데 화면에서 구분이 안 됨
  - 결과가 1건이면 item 이 리스트가 아니라 딕셔너리로 옴
"""

import json
import os
import sys
import time
from urllib.parse import unquote

import requests

# ── 엔드포인트 (probe 로 확인 완료) ─────────────────
PET_BASE = "http://apis.data.go.kr/B551011/KorPetTourService2"
PET_OP_AREA = "areaBasedList2"
PET_OP_DETAIL = "detailPetTour2"

KOR_BASE = "http://apis.data.go.kr/B551011/KorService2"
ENG_BASE = "http://apis.data.go.kr/B551011/EngService2"

COMMON = {"MobileOS": "ETC", "MobileApp": "PetPass", "_type": "json"}
ARRANGE = "A"          # 제목순. 오류나면 "" 로 비울 것
TIMEOUT = 15
SLEEP = 0.15

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
LIST_FILE = os.path.join(DATA_DIR, "pet_list.json")
DETAIL_FILE = os.path.join(DATA_DIR, "pet_detail.json")
PROGRESS_FILE = os.path.join(DATA_DIR, "pet_progress.json")
NORMALIZED_FILE = os.path.join(DATA_DIR, "pet_normalized.json")

AREA_CODES = list(range(1, 40))


# ── 인증키 ────────────────────────────────────────
def _load_env():
    """스크립트 폴더와 현재 폴더의 .env 를 환경변수로 올림 (외부 패키지 불필요)"""
    here = os.path.dirname(os.path.abspath(__file__))
    cwd = os.getcwd()
    candidates = [
        os.path.join(here, ".env"),                  # pipeline/.env
        os.path.join(os.path.dirname(here), ".env"), # 레포 루트/.env
        os.path.join(cwd, ".env"),                   # 실행한 폴더
        os.path.join(os.path.dirname(cwd), ".env"),  # 그 상위
    ]
    for path in candidates:
        if not os.path.exists(path):
            continue
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            v = v.strip().strip('"').strip("'")
            if k.strip() and v:
                os.environ.setdefault(k.strip(), v)


_load_env()
_RAW_KEY = os.getenv("TOUR_API_KEY", "")
SERVICE_KEY = unquote(_RAW_KEY) if "%" in _RAW_KEY else _RAW_KEY

NO_KEY_MSG = """
인증키를 찾을 수 없습니다.

  아래 위치 중 하나에 .env 파일을 만들고 한 줄만 넣으세요:
    petpass/pipeline/.env   (권장)
    petpass/.env

  파일 내용:
    TOUR_API_KEY=여기에인증키붙여넣기

  만드는 법:
    cd ~/petpass/pipeline
    echo "TOUR_API_KEY=여기에인증키붙여넣기" > .env
"""


def require_key():
    """수집 시작 전 1회 검사. 없으면 즉시 종료."""
    if not SERVICE_KEY:
        print(NO_KEY_MSG)
        sys.exit(1)


# ── 파일 IO ───────────────────────────────────────
def save_json(path, obj):
    """임시파일에 쓴 뒤 교체 — 저장 중 중단돼도 원본이 깨지지 않음"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def load_json(path, default):
    if os.path.exists(path):
        try:
            return json.load(open(path, encoding="utf-8"))
        except Exception:
            print(f"⚠ {path} 읽기 실패 — 새로 시작합니다")
    return default


def cid_of(item):
    for k in ("contentid", "contentId", "contentID"):
        if item.get(k):
            return str(item[k])
    return ""


# ── 호출 ──────────────────────────────────────────
def call(base, op, **params):
    """(items:list, total:int) 반환. 실패 시 RuntimeError."""
    if not SERVICE_KEY:
        raise RuntimeError("인증키 없음")

    p = {**COMMON, "serviceKey": SERVICE_KEY, **params}
    r = requests.get(f"{base}/{op}", params=p, timeout=TIMEOUT)
    text = r.text.strip()

    if not text.startswith("{"):
        raise RuntimeError(f"JSON 아님 (HTTP {r.status_code}): {text[:250]}")

    data = json.loads(text)
    resp = data.get("response")
    if resp is None:
        raise RuntimeError(f"응답 구조 예상 밖: {json.dumps(data, ensure_ascii=False)[:250]}")

    header = resp.get("header") or {}
    code = str(header.get("resultCode", ""))
    if code not in ("0000", "00", "0"):
        raise RuntimeError(f"API 오류 [{code or '?'}] {header.get('resultMsg', '메시지없음')}")

    body = resp.get("body") or {}
    items = body.get("items")
    if not isinstance(items, dict):          # 0건이면 "" 로 옴
        return [], int(body.get("totalCount") or 0)
    item = items.get("item", [])
    if isinstance(item, dict):               # 1건이면 dict 로 옴
        item = [item]
    return item, int(body.get("totalCount") or 0)


# ── 수집 ──────────────────────────────────────────
def collect_list(verbose=True):
    require_key()
    """지역 하나 끝날 때마다 저장. 중단 후 재실행하면 남은 지역만 진행."""
    rows = load_json(LIST_FILE, [])
    prog = load_json(PROGRESS_FILE, {"done_areas": []})
    done_areas = set(prog["done_areas"])
    seen = {cid_of(r) for r in rows}
    if rows and verbose:
        print(f"기존 {len(rows)}건 / 완료 지역 {len(done_areas)}개 — 이어서 진행\n")

    try:
        for area in AREA_CODES:
            if area in done_areas:
                continue
            page, got, total, failed = 1, 0, 0, False
            while True:
                kw = {"numOfRows": 100, "pageNo": page, "areaCode": area}
                if ARRANGE:
                    kw["arrange"] = ARRANGE
                try:
                    items, total = call(PET_BASE, PET_OP_AREA, **kw)
                except Exception as e:
                    print(f"  area={area} page={page} 실패: {str(e)[:70]}")
                    failed = True
                    break
                if not items:
                    break
                for it in items:
                    c = cid_of(it)
                    if c and c not in seen:
                        seen.add(c)
                        rows.append(it)
                got += len(items)
                if got >= total or len(items) < 100:
                    break
                page += 1
                time.sleep(SLEEP)

            if not failed:
                done_areas.add(area)
                if got and verbose:
                    print(f"  area={area:>2} → {got}건")
            save_json(LIST_FILE, rows)
            save_json(PROGRESS_FILE, {"done_areas": sorted(done_areas)})
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 — 여기까지 저장했습니다.")

    save_json(LIST_FILE, rows)
    save_json(PROGRESS_FILE, {"done_areas": sorted(done_areas)})
    left = len(AREA_CODES) - len(done_areas)
    print(f"\n목록 {len(rows)}건 → {os.path.basename(LIST_FILE)}"
          + (f"  (미완료 지역 {left}개)" if left else ""))
    return rows


def collect_detail(verbose=True):
    require_key()
    """contentId 마다 상세 조회. 실패는 완료로 치지 않으므로 재실행 시 재시도됨."""
    rows = load_json(LIST_FILE, [])
    if not rows:
        print("목록이 없습니다. collect_list 먼저 실행하세요.")
        return {}

    done = load_json(DETAIL_FILE, {})
    todo = [c for c in (cid_of(r) for r in rows) if c and c not in done]
    if verbose:
        print(f"상세 수집 대상 {len(todo)}건 (기존 {len(done)}건 완료)")
    if not todo:
        return done

    fails, streak = 0, 0
    try:
        for i, cid in enumerate(todo, 1):
            try:
                d, _ = call(PET_BASE, PET_OP_DETAIL, contentId=cid)
                # 성공. 결과 없으면 None = "원래 정보가 없는 곳"
                done[cid] = d[0] if d else None
                streak = 0
            except Exception as e:
                fails += 1
                streak += 1
                print(f"  {cid} 실패: {str(e)[:60]}")
                if streak >= 10:
                    print("\n⚠ 연속 10회 실패 — 트래픽 한도이거나 API 장애로 보입니다.")
                    print("  중단합니다. 다시 실행하면 실패분부터 재시도합니다.")
                    break
            if i % 50 == 0:
                save_json(DETAIL_FILE, done)
                if verbose:
                    print(f"  {i}/{len(todo)} ... 저장")
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 — 여기까지 저장합니다.")

    save_json(DETAIL_FILE, done)
    empty = sum(1 for v in done.values() if not v)
    left = len([c for c in (cid_of(r) for r in rows) if c and c not in done])
    print(f"\n상세 {len(done)}건 → {os.path.basename(DETAIL_FILE)}"
          f"  (정보없음 {empty}건, 미수집 {left}건, 실패 {fails}건)")
    return done


def merged_records():
    """목록 + 상세를 contentId 로 병합한 리스트"""
    rows = load_json(LIST_FILE, [])
    detail = load_json(DETAIL_FILE, {})
    out = []
    for r in rows:
        m = dict(r)
        m.update(detail.get(cid_of(r)) or {})
        out.append(m)
    return out
