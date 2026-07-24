#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
운영 배치 진입점 — 수집 → 정규화 → 적재.

    python sync.py              # 전체
    python sync.py collect      # 수집만
    python sync.py normalize    # 정규화만
    python sync.py upload       # 적재만

주 1회 정도 실행하면 충분합니다. 중단해도 안전하며, 다시 실행하면 이어서
진행합니다. TourAPI 인증키는 이 스크립트에서만 쓰이고 앱에는 들어가지 않습니다.
"""

import sys

from tourapi import collect_detail, collect_list


def collect():
    print("── 목록 수집 ──")
    collect_list()
    print("\n── 상세 수집 ──")
    collect_detail()


def main():
    step = sys.argv[1] if len(sys.argv) > 1 else "all"

    if step in ("all", "collect"):
        collect()

    if step in ("all", "normalize"):
        print("\n── 정규화 ──")
        import normalize
        normalize.main()

    if step in ("all", "upload"):
        print("\n── 적재 ──")
        import upload
        upload.main()


if __name__ == "__main__":
    main()
