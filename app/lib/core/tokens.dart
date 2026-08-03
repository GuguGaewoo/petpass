/// 디자인 토큰.
///
/// 방향: 따뜻한 아이보리 배경 위에 흰 카드, 넉넉한 여백, 큰 모서리.
/// 색은 짙은 초록과 밝은 민트 두 축으로 좁히고, 판정 등급에만 보조색을 쓴다.
///
/// 이전 버전은 "관인·확인증" 컨셉이었으나 관공서 앱처럼 읽혀 폐기했다.
/// 신뢰는 판정 근거와 데이터 기준일을 보여주는 것으로 이미 확보된다.
library;

import 'package:flutter/material.dart';

class T {
  // ── 바탕 ──
  static const paper = Color(0xFFFCFAF6); // 따뜻한 아이보리
  static const card = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF2EDE3); // 한 단계 낮은 면. 안내 박스 등
  static const line = Color(0xFFEDE6DB);
  static const lineStrong = Color(0xFFDDD5C8);

  // ── 글자 ──
  static const ink = Color(0xFF14342A); // 짙은 초록. 검정 대신 쓴다
  static const inkSoft = Color(0xFF6B6560);
  static const mute = Color(0xFFA8A099);

  // ── 브랜드 ──
  static const brand = Color(0xFF14342A);
  static const mint = Color(0xFF7FD4A8);
  static const onBrand = Color(0xFFF5F0E6);

  // ── 판정 ──
  // 신호등 삼색을 그대로 쓰지 않는다. 초록은 브랜드와 이어지고
  // 나머지는 채도를 낮춰 화면이 시끄러워지지 않게 한다.
  static const go = Color(0xFF0F6E56);
  static const hold = Color(0xFFB07A1F);
  static const stop = Color(0xFFA85248);
  static const unknown = Color(0xFF8C857E);

  static const goBg = Color(0xFFE4F2EA);
  static const holdBg = Color(0xFFF7EEDD);
  static const stopBg = Color(0xFFF6E9E6);
  static const unknownBg = Color(0xFFF0EDE8);

  // ── 글꼴 ──
  // 별도 폰트 의존성 없이 각 OS 의 한글 서체를 쓴다.
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
  // 이전 4.0 은 관공서 표처럼 읽혔다. 칩은 알약, 카드는 크게.
  static const r = 12.0;
  static const rCard = 18.0;
  static const rPill = 999.0;
  static const rImage = 16.0;

  // ── 간격 ──
  static const padScreen = 20.0;
  static const padCard = 16.0;
  static const gapCard = 12.0;
  static const gapSection = 26.0;

  // ── 글자 크기 ──
  // 위계를 과감하게 벌린다. 비슷한 크기가 나열되면 눈이 갈 곳이 없다.
  static const display = 28.0;
  static const title = 20.0;
  static const cardTitle = 15.5;
  static const body = 14.0;
  static const caption = 12.0;
  static const micro = 11.5;
}
