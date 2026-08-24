/// 판정 뱃지.
///
/// 실제 판정 등급은 그대로 두고, 시안의 파스텔 상태 칩 표현만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../domain/models/verdict.dart';

({Color fg, Color bg}) verdictColors(VerdictLevel l) => switch (l) {
  VerdictLevel.possible => (fg: T.go, bg: T.goBg),
  VerdictLevel.conditional => (fg: T.hold, bg: T.holdBg),
  VerdictLevel.impossible => (fg: T.stop, bg: T.stopBg),
  VerdictLevel.unknown => (fg: T.unknown, bg: T.unknownBg),
};

String verdictLabel(VerdictLevel l) => switch (l) {
  VerdictLevel.possible => '동반 가능',
  VerdictLevel.conditional => '조건부 가능',
  VerdictLevel.impossible => '동반 불가',
  VerdictLevel.unknown => '확인 필요',
};

IconData _icon(VerdictLevel l) => switch (l) {
  VerdictLevel.possible => Icons.pets_rounded,
  VerdictLevel.conditional => Icons.warning_amber_rounded,
  VerdictLevel.impossible => Icons.close_rounded,
  VerdictLevel.unknown => Icons.help_outline_rounded,
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
        horizontal: large ? 15 : 10,
        vertical: large ? 9 : 5,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(T.rPill),
        border: Border.all(color: c.fg.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(level), size: large ? 19 : 13, color: c.fg),
          SizedBox(width: large ? 7 : 4),
          Text(
            verdictLabel(level),
            style: TextStyle(
              fontFamilyFallback: T.kr,
              color: c.fg,
              fontSize: large ? 15 : 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(T.rPill),
        border: Border.all(color: T.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamilyFallback: T.kr,
          fontSize: T.micro,
          color: T.inkSoft,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
