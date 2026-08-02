/// 지도 위젯 — 플랫폼 공통 인터페이스.
///
/// 앱과 웹의 지도 라이브러리가 다르다.
///   웹  네이버 지도 JS v3
///   앱  flutter_naver_map (네이티브 SDK)
///
/// 화면 코드가 특정 라이브러리에 직접 의존하면 나중에 분리 비용이 크므로
/// 조건부 import 로 감춘다. 화면은 MapView 하나만 알면 된다.
library;

import 'package:flutter/material.dart';

import 'map_view_stub.dart'
    if (dart.library.js_interop) 'map_view_web.dart'
    as impl;

/// 지도에 찍을 지점.
class MapPin {
  const MapPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    this.color = '#1F6F4A',
  });

  final String id;
  final double lat;
  final double lng;
  final String title;

  /// 판정 등급별 색상. 갈 수 있는 곳과 없는 곳이 지도에서 구분되게 한다.
  final String color;
}

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.lat,
    required this.lng,
    this.pins = const [],
    this.zoom = 14,
    this.onPinTap,
  });

  final double lat;
  final double lng;
  final List<MapPin> pins;
  final int zoom;
  final void Function(String id)? onPinTap;

  @override
  Widget build(BuildContext context) => impl.buildMap(
    lat: lat,
    lng: lng,
    pins: pins,
    zoom: zoom,
    onPinTap: onPinTap,
  );
}
