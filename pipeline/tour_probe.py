#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
펫패스(PetPass) — TourAPI 반려동물 동반여행 데이터 실사 스크립트 (v2)

사용법:
  pip install requests
  export TOUR_API_KEY="인증키"

  python tour_probe.py smoke              # ① 목록+상세 1건 원본 확인 (필드명 파악)
  python tour_probe.py survey             # ② 전국 목록 수집 → pet_list.json
  python tour_probe.py enrich             # ③ 상세(출입조건) 수집 → pet_detail.json
  python tour_probe.py analyze            # ④ 채움률 + 문구 패턴 분석
  python tour_probe.py raw areaBasedList2 # 응답 원문 그대로 보기 (디버깅)
  python tour_probe.py probe              # 엔드포인트 재탐색
"""

import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from urllib.parse import unquote

import requests

# ─────────────────────────────────────────────────────────────
# CONFIG  ※ probe 결과 반영 완료
# ─────────────────────────────────────────────────────────────
def _load_env():
    """스크립트 폴더와 현재 폴더의 .env 를 읽어 환경변수로 올림 (외부 패키지 불필요)"""
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

  (.env 는 .gitignore 에 이미 등록돼 있습니다)
"""


def require_key():
    if not SERVICE_KEY:
        print(NO_KEY_MSG)
        sys.exit(1)


_RAW_KEY = os.getenv("TOUR_API_KEY", "")
SERVICE_KEY = unquote(_RAW_KEY) if "%" in _RAW_KEY else _RAW_KEY

PET_BASE = "http://apis.data.go.kr/B551011/KorPetTourService2"
PET_OP_AREA = "areaBasedList2"
PET_OP_DETAIL = "detailPetTour2"

KOR_BASE = "http://apis.data.go.kr/B551011/KorService2"
ENG_BASE = "http://apis.data.go.kr/B551011/EngService2"

COMMON = {"MobileOS": "ETC", "MobileApp": "PetPass", "_type": "json"}
ARRANGE = "A"                     # 정렬. 오류나면 "" 로 비우세요
AREA_CODES = list(range(1, 40))
LIST_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "pet_list.json")
DETAIL_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "pet_detail.json")
PROGRESS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "pet_progress.json")
TIMEOUT = 15
SLEEP = 0.15


# ─────────────────────────────────────────────────────────────
def call(base, op, **params):
    """(items:list, total:int) 반환. 실패 시 예외."""
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
        # data.go.kr 에러는 봉투가 다름 → 원문을 그대로 보여줌
        raise RuntimeError(f"응답 구조 예상 밖: {json.dumps(data, ensure_ascii=False)[:250]}")

    header = resp.get("header") or {}
    code = str(header.get("resultCode", ""))
    if code not in ("0000", "00", "0"):
        raise RuntimeError(f"API 오류 [{code or '?'}] {header.get('resultMsg', '메시지없음')}")

    body = resp.get("body") or {}
    items = body.get("items")
    if not isinstance(items, dict):          # 0건이면 "" 로 오는 함정
        return [], int(body.get("totalCount") or 0)
    item = items.get("item", [])
    if isinstance(item, dict):
        item = [item]
    return item, int(body.get("totalCount") or 0)


def raw(op):
    """응답 원문 그대로 출력 (디버깅용)"""
    p = {**COMMON, "serviceKey": SERVICE_KEY, "numOfRows": 1, "pageNo": 1, "areaCode": 1}
    r = requests.get(f"{PET_BASE}/{op}", params=p, timeout=TIMEOUT)
    print(f"HTTP {r.status_code}\n")
    print(r.text[:3000])


def cid_of(item):
    for k in ("contentid", "contentId", "contentID"):
        if item.get(k):
            return str(item[k])
    return ""


def save_json(path, obj):
    """임시파일에 쓴 뒤 교체 — 저장 중 중단돼도 원본이 깨지지 않음"""
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


# ─────────────────────────────────────────────────────────────
def probe():
    bases = ["http://apis.data.go.kr/B551011/KorPetTourService",
             "http://apis.data.go.kr/B551011/KorPetTourService2"]
    ops = ["areaBasedList", "areaBasedList2", "locationBasedList",
           "locationBasedList2", "detailPetTour", "detailPetTour2"]
    for b in bases:
        for op in ops:
            try:
                extra = {"contentId": "126508"} if "detail" in op else \
                        {"numOfRows": 1, "pageNo": 1, "areaCode": 1}
                items, total = call(b, op, **extra)
                print(f"  [OK]   {b.split('/')[-1]}/{op} → {len(items)}건 (total={total})")
            except Exception as e:
                print(f"  [--]   {b.split('/')[-1]}/{op} → {str(e)[:80]}")
            time.sleep(SLEEP)


# ─────────────────────────────────────────────────────────────
def smoke():
    """목록 1건 → 그 contentId로 상세까지 연달아 확인"""
    kw = {"numOfRows": 1, "pageNo": 1, "areaCode": 1}
    if ARRANGE:
        kw["arrange"] = ARRANGE
    items, total = call(PET_BASE, PET_OP_AREA, **kw)
    print(f"=== 목록 ({PET_OP_AREA}) — 서울 총 {total}건 ===\n")
    if not items:
        print("결과 없음. areaCode를 바꿔보세요.")
        return
    print(json.dumps(items[0], ensure_ascii=False, indent=2))
    print("\n--- 목록 필드명 ---")
    for k in items[0]:
        print(f"  {k}")

    cid = cid_of(items[0])
    if not cid:
        print("\ncontentid 필드를 못 찾았습니다. 위 필드명을 확인하세요.")
        return

    print(f"\n\n=== 상세 ({PET_OP_DETAIL}) — contentId={cid} ===\n")
    try:
        d, _ = call(PET_BASE, PET_OP_DETAIL, contentId=cid)
        if d:
            print(json.dumps(d[0], ensure_ascii=False, indent=2))
            print("\n--- 상세 필드명 (출입조건이 여기 있습니다) ---")
            for k in d[0]:
                print(f"  {k}")
        else:
            print("상세 0건 — 이 장소엔 반려동물 상세정보가 없습니다.")
    except Exception as e:
        print(f"상세 조회 실패: {e}")


# ─────────────────────────────────────────────────────────────
def survey():
    """지역 하나 끝날 때마다 저장. 중단 후 재실행하면 남은 지역만 진행."""
    rows = load_json(LIST_FILE, [])
    prog = load_json(PROGRESS_FILE, {"done_areas": []})
    done_areas = set(prog["done_areas"])
    seen = {cid_of(r) for r in rows}
    if rows:
        print(f"기존 {len(rows)}건 / 완료 지역 {len(done_areas)}개 — 이어서 진행\n")

    try:
        for area in AREA_CODES:
            if area in done_areas:
                continue
            page, got, total = 1, 0, 0
            failed = False
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
                done_areas.add(area)          # 성공한 지역만 완료 처리
                if got:
                    print(f"  area={area:>2} → {got}건")
            save_json(LIST_FILE, rows)
            save_json(PROGRESS_FILE, {"done_areas": sorted(done_areas)})
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 — 여기까지 저장했습니다.")

    save_json(LIST_FILE, rows)
    save_json(PROGRESS_FILE, {"done_areas": sorted(done_areas)})
    print(f"\n목록 {len(rows)}건 저장 → {LIST_FILE}")
    if len(done_areas) < len(AREA_CODES):
        print(f"미완료 지역 {len(AREA_CODES) - len(done_areas)}개 — survey 다시 실행하면 이어집니다")
    else:
        print("다음: python tour_probe.py enrich")


def enrich():
    """contentId마다 상세 조회. 실패는 완료로 치지 않으므로 재실행 시 재시도됨."""
    rows = load_json(LIST_FILE, [])
    if not rows:
        print(f"{LIST_FILE}이 없습니다. survey 먼저 실행하세요.")
        return
    done = load_json(DETAIL_FILE, {})
    if done:
        print(f"기존 {len(done)}건 완료 — 이어서 진행")

    todo = [c for c in (cid_of(r) for r in rows) if c and c not in done]
    print(f"수집 대상 {len(todo)}건\n")
    if not todo:
        print("이미 전부 수집됐습니다.")
        return

    fails, streak = 0, 0
    try:
        for i, cid in enumerate(todo, 1):
            try:
                d, _ = call(PET_BASE, PET_OP_DETAIL, contentId=cid)
                # 성공. 결과가 없으면 None으로 기록 = "원래 정보가 없는 곳"
                done[cid] = d[0] if d else None
                streak = 0
            except Exception as e:
                fails += 1
                streak += 1
                print(f"  {cid} 실패: {str(e)[:60]}")
                if streak >= 10:
                    print("\n⚠ 연속 10회 실패 — 트래픽 한도이거나 API 장애로 보입니다.")
                    print("  중단합니다. 나중에 enrich를 다시 실행하면 실패분부터 재시도합니다.")
                    break
            if i % 50 == 0:
                save_json(DETAIL_FILE, done)
                print(f"  {i}/{len(todo)} ... 저장")
            time.sleep(SLEEP)
    except KeyboardInterrupt:
        print("\n중단됨 — 여기까지 저장합니다.")

    save_json(DETAIL_FILE, done)
    empty = sum(1 for v in done.values() if not v)
    left = len([c for c in (cid_of(r) for r in rows) if c and c not in done])
    print(f"\n완료 {len(done)}건 저장 → {DETAIL_FILE}")
    print(f"  그중 상세정보 없음 {empty}건 ({empty/max(len(done),1)*100:.1f}%)")
    if left:
        print(f"  미수집 {left}건 — enrich 다시 실행하면 이어집니다 (실패 {fails}건)")


# ─────────────────────────────────────────────────────────────
WEIGHT_RE = re.compile(r"(\d+(?:\.\d+)?)\s*(?:kg|KG|Kg|킬로|㎏)")
KEYWORDS = {
    "소형견": ["소형견", "소형"], "중형견": ["중형견", "중형"], "대형견": ["대형견", "대형"],
    "맹견": ["맹견"], "견종언급": ["견종", "품종"],
    "케이지/이동장": ["케이지", "이동장", "켄넬", "캐리어"],
    "목줄": ["목줄", "리드줄", "하네스"], "입마개": ["입마개"],
    "실내": ["실내", "매장 내", "객실"], "야외": ["야외", "테라스", "실외"],
    "예방접종": ["예방접종", "접종", "광견병"], "추가요금": ["추가요금", "추가 요금"],
    "두수제한": ["마리"], "배변": ["배변", "패드"],
}


def analyze():
    rows = json.load(open(LIST_FILE, encoding="utf-8"))
    detail = json.load(open(DETAIL_FILE, encoding="utf-8")) if os.path.exists(DETAIL_FILE) else {}

    merged = []
    for r in rows:
        m = dict(r)
        m.update(detail.get(cid_of(r)) or {})
        merged.append(m)
    print(f"분석 대상 {len(merged)}건 (상세 병합 {len(detail)}건)\n")

    fill = defaultdict(int)
    for r in merged:
        for k, v in r.items():
            if v not in (None, "", " "):
                fill[k] += 1
    print("=== 필드별 채움률 ===")
    for k, n in sorted(fill.items(), key=lambda x: -x[1]):
        pct = n / len(merged) * 100
        print(f"  {k:<26} {pct:5.1f}%  {'█' * int(pct / 3.4)}")

    lens = defaultdict(list)
    for r in merged:
        for k, v in r.items():
            if isinstance(v, str) and v.strip():
                lens[k].append(len(v))
    text_fields = [k for k, v in lens.items() if sum(v) / len(v) >= 15]
    print("\n=== 자연어(조건 문구) 필드 후보 ===")
    for k in text_fields:
        print(f"  {k}  (평균 {sum(lens[k])/len(lens[k]):.0f}자, {len(lens[k])}건)")

    weights, kw = Counter(), Counter()
    for r in merged:
        blob = " ".join(str(v) for v in r.values() if isinstance(v, str))
        for m in WEIGHT_RE.findall(blob):
            weights[m] += 1
        for label, pats in KEYWORDS.items():
            if any(p in blob for p in pats):
                kw[label] += 1

    print("\n=== 체중 제한 표현 ===")
    for w, n in weights.most_common(15) or [("(없음)", 0)]:
        print(f"  {w}kg → {n}건")

    print("\n=== 조건 키워드 빈도 ===")
    for label, n in kw.most_common():
        print(f"  {label:<14} {n:>5}건 ({n/len(merged)*100:4.1f}%)")

    print("\n=== 조건 문구 샘플 20개 ===")
    shown = 0
    for r in merged:
        for k in text_fields:
            v = r.get(k)
            if isinstance(v, str) and (WEIGHT_RE.search(v) or "동반" in v):
                print(f"  [{k}] {v[:110]}")
                shown += 1
                break
        if shown >= 20:
            break


# ─────────────────────────────────────────────────────────────
# profile — 실제 펫 필드 전용 분석 (스키마 확정용 핵심 도구)
# ─────────────────────────────────────────────────────────────
PET_FIELDS = ["acmpyTypeCd", "acmpyPsblCpam", "acmpyNeedMtr", "relaAcdntRiskMtr",
              "relaPosesFclty", "relaFrnshPrdlst", "relaRntlPrdlst",
              "relaPurcPrdlst", "etcAcmpyInfo"]
TYPE_NAME = {"12": "관광지", "14": "문화시설", "28": "레포츠",
             "32": "숙박", "38": "쇼핑", "39": "음식점"}
GUIDE_DOG = ["안내견", "장애인"]


def profile():
    rows = json.load(open(LIST_FILE, encoding="utf-8"))
    detail = json.load(open(DETAIL_FILE, encoding="utf-8")) if os.path.exists(DETAIL_FILE) else {}
    merged = []
    for r in rows:
        m = dict(r)
        m.update(detail.get(cid_of(r)) or {})
        merged.append(m)
    n = len(merged)
    print(f"전국 {n}건 (상세 {len(detail)}건)\n")

    print("=== 시설 유형 분포 ===")
    for t, c in Counter(r.get("contenttypeid", "?") for r in merged).most_common():
        print(f"  {TYPE_NAME.get(t, t):<8} {c:>5}건")

    print("\n=== 펫 필드 채움률 ===")
    for f in PET_FIELDS:
        c = sum(1 for r in merged if str(r.get(f, "")).strip())
        print(f"  {f:<18} {c/n*100:5.1f}%  {'█' * int(c/n*30)}  ({c}건)")

    print("\n=== acmpyTypeCd 고유값 (판정 1차 기준) ===")
    for v, c in Counter(r.get("acmpyTypeCd", "").strip() or "(빈값)"
                        for r in merged).most_common():
        print(f"  {c:>5}건 ({c/n*100:4.1f}%)  {v}")

    print("\n=== acmpyPsblCpam 고유값 상위 30 (판정 2차 기준) ===")
    cpam = Counter(r.get("acmpyPsblCpam", "").strip() or "(빈값)" for r in merged)
    for v, c in cpam.most_common(30):
        print(f"  {c:>4}건  {v[:80]}")
    print(f"  ...총 {len(cpam)}가지 표현")

    print("\n=== 판정에 결정적인 신호 ===")
    guide = [r for r in merged
             if any(g in str(r.get("acmpyPsblCpam", "")) for g in GUIDE_DOG)]
    print(f"  안내견 전용으로 보이는 곳      {len(guide):>5}건 ({len(guide)/n*100:4.1f}%)")
    trap = [r for r in guide if "가능" in str(r.get("acmpyTypeCd", ""))]
    print(f"   └ 그중 acmpyTypeCd는 '가능'   {len(trap):>5}건  ← 오인 위험 케이스")

    wt = [r for r in merged
          if WEIGHT_RE.search(" ".join(str(r.get(f, "")) for f in PET_FIELDS))]
    print(f"  체중(kg) 표현 있는 곳          {len(wt):>5}건 ({len(wt)/n*100:4.1f}%)")
    sz = [r for r in merged
          if any(k in " ".join(str(r.get(f, "")) for f in PET_FIELDS)
                 for k in ["소형견", "중형견", "대형견"])]
    print(f"  견종 크기 표현 있는 곳         {len(sz):>5}건 ({len(sz)/n*100:4.1f}%)")

    print("\n=== acmpyNeedMtr 고유값 상위 20 (준비물 체크리스트 원천) ===")
    for v, c in Counter(r.get("acmpyNeedMtr", "").strip() or "(빈값)"
                        for r in merged).most_common(20):
        print(f"  {c:>4}건  {v[:80]}")

    print("\n=== 체중 언급 실제 문구 15개 ===")
    for r in wt[:15]:
        for f in PET_FIELDS:
            v = str(r.get(f, ""))
            if WEIGHT_RE.search(v):
                print(f"  [{f}] {v[:100]}")
                break

    print("\n=== 오인 위험 케이스 샘플 10개 (PT 자료용) ===")
    for r in trap[:10]:
        print(f"  {r.get('title')}")
        print(f"    유형: {r.get('acmpyTypeCd')} / 가능동물: {r.get('acmpyPsblCpam')}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "smoke"
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    if mode not in ("analyze", "profile"):   # 이 둘은 저장된 파일만 읽음
        require_key()
    {"probe": probe, "smoke": smoke, "survey": survey, "enrich": enrich,
     "analyze": analyze, "profile": profile,
     "raw": lambda: raw(arg or PET_OP_AREA)}.get(mode, smoke)()
