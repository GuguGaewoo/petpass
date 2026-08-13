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
            opacity: dense ? .055 : .032,
            child: const _PawPattern(),
          ),
        ),
      ],
    );
  }
}

class _PawPattern extends Stateless