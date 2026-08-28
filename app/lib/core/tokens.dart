/// 디자인 토큰.
///
/// 실제 기능 구조는 유지하고, PetPass 시안의 아이보리 + 라벤더 +
/// 말랑한 카드 톤만 공통 스타일로 적용한다.
library;

import 'package:flutter/material.dart';

class T {
  // ── 바탕 ──
  static const paper = Color(0xFFFFF9F1);
  static const card = Color(0xFFFFFEFC);
  static const sunken = Color(0xFFF7F1FB);
  static const line = Color(0xFFEDE4F1);
  static const lineStrong = Color(0xFFDCCFE5);

  // ── 글자 ──
  static const ink = Color(0xFF332D3D);
  static const inkSoft = Color(0xFF716A78);
  static const mute = Color(0xFFA69EAA);

  // ── 브랜드 ──
  static const brand = Color(0xFF8B72C8);
  static const brandDeep = Color(0xFF7458B5);
  static const brandSoft = Color(0xFFECE3F8);
  static const brandMist = Color(0xFFF8F3FC);
  static const peach = Color(0xFFF4B27F);
  static const mint = Color(0xFFA9CFAF);
  static const paw = Color(0xFFDCC5AA);
  static const onBrand = Color(0xFFFFFFFF);

  // ── 판정 ──
  // 판정 의미는 기존 색 체계를 유지하되 전체 팔레트에 맞춰 채도를 낮춘다.
  static const go = Color(0xFF628F66);
  static const hold = Color(0xFFB88236);
  static const stop = Color(0xFFBD6962);
  static const unknown = Color(0xFF817985);

  static const goBg = Color(0xFFEAF4E6);
  static const holdBg = Color(0xFFFFF0D8);
  static const stopBg = Color(0xFFFBE7E3);
  static const unknownBg = Color(0xFFF0EDF2);

  // ── 글꼴 ──
  static const kr = <String>[
    'Apple SD Gothic Neo',
    'Pretendard',
    'Noto Sans KR',
    'Malgun Gothic',
    'sans-serif',
  ];

  /// 수치·날짜·식별자용 고정폭
  static const monoStack = <String>[
    'SF Mono',
    'ui-monospace',
    'Menlo',
    'Consolas',
    'monospace',
  ];

  static const mono = TextStyle(
    fontFamilyFallback: monoStack,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── 모서리 ──
  static const r = 16.0;
  static const rCard = 22.0;
  static const rPill = 999.0;
  static const rImage = 18.0;

  // ── 간격 ──
  static const padScreen = 20.0;
  static const padCard = 17.0;
  static const gapCard = 12.0;
  static const gapSection = 28.0;

  // ── 그림자 ──
  static const softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x120C0713), blurRadius: 22, offset: Offset(0, 8)),
  ];

  // ── 글자 크기 ──
  static const display = 30.0;
  static const title = 21.0;
  static const cardTitle = 16.0;
  static const body = 14.0;
  static const caption = 12.0;
  static const micro = 11.5;
}
