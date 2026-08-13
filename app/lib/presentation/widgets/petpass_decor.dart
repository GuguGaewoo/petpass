/// PetPass 공통 장식 요소.
///
/// 기능/입력 이벤트에는 관여하지 않는 순수 UI 위젯이다.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// 화면 위에 매우 옅은 발바닥 패턴을 얹는다.
/// IgnorePointer로 장식이 터치/스크롤을 가로채지 않게 한다.
class PetPassBackdrop extends StatelessWidget {
  const PetPassBackdrop({
    super.key,
    required this.child,
    this.dense = false,
  });

  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: Opacity(
            opacity: dense ? .060 : .038,
            child: const _PawPattern(),
          ),
        ),
      ],
    );
  }
}

class _PawPattern extends StatelessWidget {
  const _PawPattern();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            _paw(left: w * .025, top: h * .08, size: 25, turn: -.30),
            _paw(right: w * .035, top: h * .18, size: 17, turn: .22),
            _paw(left: w * .035, top: h * .43, size: 15, turn: .36),
            _paw(right: w * .035, top: h * .52, size: 22, turn: -.20),
            _paw(left: w * .025, top: h * .73, size: 18, turn: .16),
            _paw(right: w * .035, top: h * .86, size: 16, turn: -.36),
          ],
        );
      },
    );
  }

  Widget _paw({
    double? left,
    double? right,
    required double top,
    required double size,
    required double turn,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Transform.rotate(
        angle: turn,
        child: Icon(Icons.pets_rounded, size: size, color: T.brand),
      ),
    );
  }
}

/// 별도 이미지 에셋 없이 그리는 가벼운 PetPass 강아지 마스코트.
/// 앱 기능이나 상태와 연결되지 않는다.
class PetPassMascot extends StatelessWidget {
  const PetPassMascot({super.key, this.size = 108});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final face = s * .66;
    final earW = s * .24;
    final earH = s * .36;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: T.brandSoft,
              border: Border.all(color: T.card, width: 5),
              boxShadow: T.softShadow,
            ),
          ),
          Positioned(
            left: s * .12,
            top: s * .25,
            child: Transform.rotate(
              angle: -.34,
              child: Container(
                width: earW,
                height: earH,
                decoration: BoxDecoration(
                  color: T.paw,
                  borderRadius: BorderRadius.circular(earW),
                ),
              ),
            ),
          ),
          Positioned(
            right: s * .12,
            top: s * .25,
            child: Transform.rotate(
              angle: .34,
              child: Container(
                width: earW,
                height: earH,
                decoration: BoxDecoration(
                  color: T.paw,
                  borderRadius: BorderRadius.circular(earW),
                ),
              ),
            ),
          ),
          Container(
            width: face,
            height: face,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF4DE),
              border: Border.all(color: const Color(0xFFF0D7B8), width: 1.2),
            ),
          ),
          Positioned(
            top: s * .39,
            left: s * .35,
            child: _dot(s * .055, T.ink),
          ),
          Positioned(
            top: s * .39,
            right: s * .35,
            child: _dot(s * .055, T.ink),
          ),
          Positioned(
            top: s * .50,
            child: Container(
              width: s * .105,
              height: s * .075,
              decoration: BoxDecoration(
                color: T.ink,
                borderRadius: BorderRadius.circular(s),
              ),
            ),
          ),
          Positioned(
            top: s * .57,
            child: Container(
              width: s * .16,
              height: s * .07,
              decoration: BoxDecoration(
                color: const Color(0xFFF3A1A8),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(s),
                ),
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: 4,
            child: Container(
              width: s * .29,
              height: s * .29,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: T.brand,
              ),
              child: Icon(
                Icons.pets_rounded,
                size: s * .15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
