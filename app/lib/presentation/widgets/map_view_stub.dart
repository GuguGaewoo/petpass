/// 지도 미지원 플랫폼용 대체 구현.
///
/// 지도를 못 그려도 기능이 중단되지 않아야 한다.
/// 앱(Android)용 구현이 붙기 전까지 여기로 떨어진다.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'map_view.dart';

Widget buildMap({
  required double lat,
  required double lng,
  required List<MapPin> pins,
  required int zoom,
  void Function(String id)? onPinTap,
}) {
  return Container(
    color: T.paper,
    alignment: Alignment.center,
    child: const Text(
      '이 환경에서는 지도를 표시할 수 없습니다',
      style: TextStyle(fontFamilyFallback: T.kr, fontSize: 13, color: T.mute),
    ),
  );
}
