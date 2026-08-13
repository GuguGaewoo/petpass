/// PetPass 공통 장식 요소.
///
/// 기능/입력 이벤트에는 관여하지 않는 순수 UI 위젯이다.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Navigator 위에 옅은 발바닥·구름 장식을 얹는다.
/// IgnorePointer라 입력/스크롤 동작을 가로채지 않는다.
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
            opacity: dense ? .075 : .045,
            child: const _PetPassPattern(),
          ),
        ),
      ],
    );
  }
}

class _PetPassPattern extends StatelessWidget {
  const _PetPassPattern();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            _paw(left: w * .035, top: h * .055, size: 25, turn: -.24),
            _cloud(right: w * .08, top: h * .08, width: 58),
            _paw(right: w * .035, top: h * .20, size: 17, turn: .28),
            _cloud(left: w * .06, top: h * .33, width: 43),
            _paw(left: w * .035, top: h * .47, size: 16, turn: .34),
            _paw(right: w * .04, top: h * .57, size: 23, turn: -.22),
            _cloud(right: w * .12, top: h * .70, width: 52),
            _paw(left: w * .03, top: h * .79, size: 19, turn: .14),
            _paw(right: w * .035, top: h * .90, size: 16, turn: -.34),
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

  Widget _cloud({
    double? left,
    double? right,
    required double top,
    required double width,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: SizedBox(
        width: width,
        height: width * .42,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: width,
              height: width * .24,
              decoration: BoxDecoration(
                color: T.brand,
                borderRadius: BorderRadius.circular(width),
              ),
            ),
            Positioned(
              left: width * .16,
              bottom: width * .08,
              child: _circle(width * .28, T.brand),
            ),
            Positioned(
              right: width * .20,
              bottom: width * .07,
              child: _circle(width * .35, T.brand),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// 시안의 복슬복슬한 비숑 계열 캐릭터를 Flutter 도형으로 재구성한 마스코트.
/// 실제 이미지 에셋이 들어오면 이 위젯만 Image.asset 기반으로 교체하면 된다.
class PetPassMascot extends StatelessWidget {
  const PetPassMascot({super.key, this.size = 116, this.withMeadow = false});

  final double size;
  final bool withMeadow;

  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s * (withMeadow ? 1.42 : 1.12),
      height: s * (withMeadow ? 1.22 : 1.08),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (withMeadow) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Meadow(width: s * 1.40, height: s * .32),
            ),
            Positioned(
              left: s * .08,
              top: s * .08,
              child: _SoftCloud(width: s * .31),
            ),
            Positioned(
              right: s * .05,
              top: s * .23,
              child: Transform.rotate(
                angle: .18,
                child: Icon(
                  Icons.pets_rounded,
                  size: s * .17,
                  color: T.paw.withValues(alpha: .70),
                ),
              ),
            ),
          ],
          Positioned(
            top: withMeadow ? s * .05 : 0,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6DCF7),
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: T.softShadow,
              ),
            ),
          ),
          Positioned(
            top: withMeadow ? s * .22 : s * .17,
            child: _FluffyDog(size: s * .77),
          ),
          Positioned(
            right: withMeadow ? s * .10 : 0,
            bottom: withMeadow ? s * .10 : s * .03,
            child: Container(
              width: s * .27,
              height: s * .27,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA990E3), Color(0xFF7658BC)],
                ),
              ),
              child: Icon(
                Icons.pets_rounded,
                size: s * .14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FluffyDog extends StatelessWidget {
  const _FluffyDog({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    const fur = Color(0xFFFFF7E8);
    const furShade = Color(0xFFF1DEC0);
    const ear = Color(0xFFE8C89E);

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: s * .01,
            child: Container(
              width: s * .55,
              height: s * .43,
              decoration: BoxDecoration(
                color: fur,
                borderRadius: BorderRadius.circular(s),
                border: Border.all(color: furShade, width: 1),
              ),
            ),
          ),
          Positioned(
            left: s * .13,
            top: s * .27,
            child: Transform.rotate(
              angle: -.26,
              child: Container(
                width: s * .21,
                height: s * .36,
                decoration: BoxDecoration(
                  color: ear,
                  borderRadius: BorderRadius.circular(s),
                ),
              ),
            ),
          ),
          Positioned(
            right: s * .13,
            top: s * .27,
            child: Transform.rotate(
              angle: .26,
              child: Container(
                width: s * .21,
                height: s * .36,
                decoration: BoxDecoration(
                  color: ear,
                  borderRadius: BorderRadius.circular(s),
                ),
              ),
            ),
          ),
          ..._fluff(s, fur, furShade),
          Positioned(
            top: s * .34,
            left: s * .34,
            child: _dot(s * .058, T.ink),
          ),
          Positioned(
            top: s * .34,
            right: s * .34,
            child: _dot(s * .058, T.ink),
          ),
          Positioned(
            top: s * .46,
            child: Container(
              width: s * .11,
              height: s * .075,
              decoration: BoxDecoration(
                color: T.ink,
                borderRadius: BorderRadius.circular(s),
              ),
            ),
          ),
          Positioned(
            top: s * .53,
            child: Container(
              width: s * .16,
              height: s * .075,
              decoration: BoxDecoration(
                color: const Color(0xFFF29AA1),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(s),
                ),
              ),
            ),
          ),
          Positioned(
            left: s * .22,
            bottom: 0,
            child: _paw(s * .20, fur, furShade),
          ),
          Positioned(
            right: s * .22,
            bottom: 0,
            child: _paw(s * .20, fur, furShade),
          ),
        ],
      ),
    );
  }

  static List<Widget> _fluff(double s, Color fur, Color shade) {
    final dots = <({double x, double y, double d})>[
      (x: .23, y: .17, d: .28),
      (x: .38, y: .10, d: .30),
      (x: .55, y: .12, d: .30),
      (x: .68, y: .20, d: .27),
      (x: .18, y: .33, d: .30),
      (x: .33, y: .29, d: .34),
      (x: .52, y: .28, d: .35),
      (x: .66, y: .34, d: .31),
      (x: .25, y: .46, d: .31),
      (x: .43, y: .43, d: .35),
      (x: .59, y: .45, d: .32),
    ];
    return [
      for (final p in dots)
        Positioned(
          left: s * p.x,
          top: s * p.y,
          child: Container(
            width: s * p.d,
            height: s * p.d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fur,
              border: Border.all(color: shade, width: .7),
            ),
          ),
        ),
    ];
  }

  static Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  static Widget _paw(double size, Color fur, Color shade) => Container(
        width: size,
        height: size * .72,
        decoration: BoxDecoration(
          color: fur,
          borderRadius: BorderRadius.circular(size),
          border: Border.all(color: shade, width: .7),
        ),
      );
}

class _SoftCloud extends StatelessWidget {
  const _SoftCloud({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE8EEF2);
    return SizedBox(
      width: width,
      height: width * .45,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: width,
            height: width * .24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(width),
            ),
          ),
          Positioned(left: width * .16, bottom: width * .08, child: _blob(width * .28, color)),
          Positioned(right: width * .20, bottom: width * .07, child: _blob(width * .36, color)),
        ],
      ),
    );
  }

  static Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _Meadow extends StatelessWidget {
  const _Meadow({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: width,
            height: height * .72,
            decoration: BoxDecoration(
              color: const Color(0xFFD8E7B5),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
          Positioned(
            left: width * .08,
            bottom: height * .34,
            child: _bush(height * .62, const Color(0xFFB8D8A0)),
          ),
          Positioned(
            right: width * .10,
            bottom: height * .28,
            child: _bush(height * .54, const Color(0xFFC6E0A8)),
          ),
          Positioned(left: width * .19, bottom: height * .16, child: _flower(8, const Color(0xFFF7B8B1))),
          Positioned(right: width * .24, bottom: height * .20, child: _flower(7, const Color(0xFFF1D589))),
          Positioned(right: width * .12, bottom: height * .10, child: _flower(6, const Color(0xFFC4A6E4))),
        ],
      ),
    );
  }

  static Widget _bush(double size, Color color) => Container(
        width: size,
        height: size * .55,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      );

  static Widget _flower(double size, Color color) => Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.local_florist_rounded, size: size * 2.1, color: color),
          Container(
            width: size * .45,
            height: size * .45,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0A8),
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
}

/// 시안의 보라색 그라데이션 + 우측 발바닥 CTA.
/// 기존 onPressed 콜백만 받아 기능을 그대로 보존한다.
class PetPassPrimaryButton extends StatelessWidget {
  const PetPassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.pets_rounded,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(T.rPill),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(T.rPill),
            child: Ink(
              height: height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA78DE3), Color(0xFF7657BD)],
                ),
                borderRadius: BorderRadius.circular(T.rPill),
                border: Border.all(color: Colors.white.withValues(alpha: .55)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x338B72C8),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamilyFallback: T.kr,
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    child: Icon(icon, size: 21, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
