/// 디자인 토큰.
///
/// 이 서비스는 공공데이터를 근거로 출입 가능 여부를 확인해주는 도구다.
/// 신호등 원색 대신 관인·확인증에 가까운 깊고 낮은 채도를 쓴다.
library;

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class T {
  // ── 색 ──
  static const paper = Color(0xFFF2F4F1);   // 재생지 느낌의 서늘한 바탕
  static const card = Color(0xFFFCFDFB);
  static const ink = Color(0xFF171B18);
  static const inkSoft = Color(0xFF5A625C);
  static const line = Color(0xFFDDE2DC);

  static const go = Color(0xFF1F6F4A);      // 가능
  static const hold = Color(0xFF9A6209);    // 조건부 가능
  static const stop = Color(0xFFA32F2A);    // 불가
  static const mute = Color(0xFF6E7671);    // 정보없음

  static const goBg = Color(0xFFE6EFE9);
  static const holdBg = Color(0xFFF4EDDF);
  static const stopBg = Color(0xFFF2E4E3);
  static const muteBg = Color(0xFFE9ECE9);

  // ── 글꼴 ──
  // 별도 폰트 의존성 없이 각 OS 의 한글 서체를 쓴다.
  static const kr = <String>[
    'Apple SD Gothic Neo', 'Pretendard', 'Noto Sans KR',
    'Malgun Gothic', 'sans-serif',
  ];

  /// 수치·날짜·식별자용 고정폭. 기록물처럼 읽히게 한다.
  static const monoStack = <String>[
    'SF Mono', 'ui-monospace', 'Menlo', 'Consolas', 'monospace',
  ];

  static const mono = TextStyle(
    fontFamilyFallback: monoStack,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── 간격 ──
  static const r = 4.0;   // 모서리는 거의 각지게. 서류의 인상
  static const rCard = 10.0;
}
