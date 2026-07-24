/// 판정 뱃지 — 이 앱의 시그니처.
///
/// 확인증에 찍힌 도장처럼 보이게 만든다. 각진 모서리, 굵은 테두리,
/// 넓은 자간. 화면에서 과감한 요소는 여기 하나뿐이고 나머지는 조용하다.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../domain/models/verdict.dart';

({Color fg, Color bg}) verdictColors(VerdictLevel l) => switch (l) {
      VerdictLevel.possible => (fg: T.go, bg: T.goBg),
      VerdictLevel.conditional => (fg: T.hold, bg: T.holdBg),
      VerdictLevel.impossible => (fg: T.stop, bg: T.stopBg),
      VerdictLevel.unknown => (fg: T.mute, bg: T.muteBg),
    };

class VerdictBadge extends StatelessWidget {
  const VerdictBadge(this.level, {super.key, this.large = false});

  final VerdictLevel level;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = verdictColors(level);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 18 : 10, vertical: large ? 10 : 5),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.fg, width: large ? 2 : 1.2),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontFamilyFallback: T.kr,
          color: c.fg,
          fontSize: large ? 20 : 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: large ? 2.0 : 0.6,
          height: 1.1,
        ),
      ),
    );
  }
}

/// 등급을 바꾸지 않는 부가 정보 태그.
class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Text(label,
          style: const TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 11.5,
              color: T.inkSoft,
              height: 1.2)),
    );
  }
}
