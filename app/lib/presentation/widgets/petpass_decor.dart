/// PetPass 공통 장식 요소.
///
/// 마스코트/장식 이미지는 앱 번들 assets를 사용하고,
/// 기능/입력 이벤트에는 관여하지 않는다.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

class PetPassAssets {
  static const logo = 'assets/branding/petpass_logo.png';
  static const appIcon1024 = 'assets/branding/app_icon_1024.png';
  static const appIcon512 = 'assets/branding/app_icon_512.png';
  static const mascotProfile = 'assets/branding/mascot_profile.png';
  static const mascotSitting = 'assets/branding/mascot_sitting.png';
  static const mascotTravel = 'assets/branding/mascot_travel.png';
  static const mascotSleeping = 'assets/branding/mascot_sleeping.png';

  static const clouds = 'assets/decor/clouds.png';
  static const grassFlowers = 'assets/decor/grass_flowers.png';
  static const heart = 'assets/decor/heart.png';
  static const pawPin = 'assets/decor/paw_pin.png';
  static const pawPrint = 'assets/decor/paw_print.png';
}

enum PetPassMascotKind { profile, sitting, travel, sleeping }

int _cacheWidth(BuildContext context, double logicalWidth, {int max = 768}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final target = (logicalWidth * dpr).ceil();
  return target.clamp(1, max).toInt();
}

/// 화면 가장자리만 장식하는 발바닥 패턴.
/// 16~24px 장식에는 대형 PNG를 디코딩하지 않고 Material 벡터 아이콘을 쓴다.
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
          child: _PawEdgePattern(opacity: dense ? .10 : .055),
        ),
      ],
    );
  }
}

class _PawEdgePattern extends StatelessWidget {
  const _PawEdgePattern({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return Stack(
          children: [
            _paw(left: -5, top: h * .08, size: 24, turn: -.28),
            _paw(right: -4, top: h * .21, size: 18, turn: .24),
            _paw(left: -3, top: h * .48, size: 16, turn: .30),
            _paw(right: -6, top: h * .61, size: 23, turn: -.20),
            _paw(left: -5, top: h * .80, size: 19, turn: .12),
            _paw(right: -4, top: h * .91, size: 16, turn: -.32),
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
        child: Icon(
          Icons.pets_rounded,
          size: size,
          color: T.brand.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// 번들 이미지 기반 PetPass 마스코트.
/// 표시 크기와 기기 DPR에 맞춰 디코딩 해상도를 제한해 래스터 캐시 낭비를 줄인다.
class PetPassMascot extends StatelessWidget {
  const PetPassMascot({
    super.key,
    this.size = 116,
    this.withMeadow = false,
    this.kind = PetPassMascotKind.sitting,
  });

  final double size;
  final bool withMeadow;
  final PetPassMascotKind kind;

  String get _asset => switch (kind) {
        PetPassMascotKind.profile => PetPassAssets.mascotProfile,
        PetPassMascotKind.sitting => PetPassAssets.mascotSitting,
        PetPassMascotKind.travel => PetPassAssets.mascotTravel,
        PetPassMascotKind.sleeping => PetPassAssets.mascotSleeping,
      };

  @override
  Widget build(BuildContext context) {
    if (!withMeadow) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          _asset,
          fit: BoxFit.contain,
          cacheWidth: _cacheWidth(context, size, max: 512),
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    final s = size;
    final totalWidth = s * 1.55;
    return SizedBox(
      width: totalWidth,
      height: s * 1.25,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: s * .08,
            right: s * .08,
            top: 0,
            child: Opacity(
              opacity: .72,
              child: Image.asset(
                PetPassAssets.clouds,
                height: s * .48,
                fit: BoxFit.contain,
                cacheWidth: _cacheWidth(context, totalWidth - s * .16),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              PetPassAssets.grassFlowers,
              height: s * .40,
              fit: BoxFit.fill,
              cacheWidth: _cacheWidth(context, totalWidth),
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            top: s * .02,
            child: SizedBox(
              width: s,
              height: s,
              child: Image.asset(
                _asset,
                fit: BoxFit.contain,
                cacheWidth: _cacheWidth(context, s, max: 512),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 작은 UI 발바닥은 PNG 대신 벡터 아이콘을 사용한다.
class PetPassPawIcon extends StatelessWidget {
  const PetPassPawIcon({
    super.key,
    this.size = 18,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.pets_rounded,
      size: size,
      color: color ?? T.brand,
    );
  }
}

/// 앱의 주요 CTA를 한 스타일로 통일한다.
/// 텍스트와 발바닥을 같은 Row에 두어 좁은 화면에서도 겹치지 않는다.
class PetPassPrimaryButton extends StatelessWidget {
  const PetPassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: T.brand,
          foregroundColor: T.onBrand,
          disabledBackgroundColor: T.line,
          disabledForegroundColor: T.mute,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(T.rPill),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  fontFamilyFallback: T.kr,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 9),
            PetPassPawIcon(
              size: 19,
              color: onPressed == null ? T.mute : T.onBrand,
            ),
          ],
        ),
      ),
    );
  }
}
