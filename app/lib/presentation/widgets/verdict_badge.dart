/// 판정 뱃지.
///
/// 이전에는 각진 테두리에 넓은 자간으로 도장처럼 만들었으나,
/// 관공서 서류처럼 읽혀 부드러운 알약 형태로 바꿨다.
/// 색 자체가 판정을 전달하므로 형태까지 강할 필요가 없다.
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

/// 목록·상세에서 쓰는 짧은 라벨.
/// 뱃지가 답하는 질문은 하나다: "데려가면 들어갈 수 있나?"
String verdictLabel(VerdictLevel l) => switch (l) {
  VerdictLevel.possible => '갈 수 있어요',
  VerdictLevel.conditional => '준비물이 필요해요',
  VerdictLevel.impossible => '갈 수 없어요',
  VerdictLevel.unknown => '정보가 없어요',
};

IconData _icon(VerdictLevel l) => switch (l) {
  VerdictLevel.possible => Icons.check_rounded,
  VerdictLevel.conditional => Icons.backpack_outlined,
  VerdictLevel.impossible => Icons.block_rounded,
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
        horizontal: large ? 14 : 10,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(T.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(level), size: large ? 16 : 13, color: c.fg),
          SizedBox(width: large ? 6 : 4),
          Text(
            verdictLabel(level),
            style: TextStyle(
              fontFamilyFallback: T.kr,
              color: c.fg,
              fontSize: large ? 14.5 : 12,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: T.sunken,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamilyFallback: T.kr,
          fontSize: T.micro,
          color: T.inkSoft,
          height: 1.2,
        ),
      ),
    );
  }
}
