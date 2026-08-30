/// 앱용 지도 — flutter_naver_map (네이티브 SDK).
///
/// 웹은 JS SDK 를 쓴다. 두 구현을 map_view.dart 의 조건부 import 로 감춰
/// 화면 코드는 어느 쪽인지 몰라도 된다.
///
/// 주의: 이 패키지는 Impeller 렌더링을 지원하지 않는다.
///       AndroidManifest 에서 반드시 꺼야 지도가 그려진다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/env.dart';
import '../../core/tokens.dart';
import 'map_view.dart';

bool _initialized = false;

/// SDK 초기화. 지도를 처음 띄울 때 한 번만 수행한다.
///
/// AndroidManifest 에 키를 박지 않고 여기서 초기화하는 이유:
///   --dart-define 으로 넘긴 값은 매니페스트에서 읽을 수 없다.
///   키를 소스나 매니페스트에 하드코딩하지 않으려면 코드 초기화가 맞다.
Future<void> _ensureInit() async {
  if (_initialized) {
    return;
  }
  // NaverMapSdk.instance.initialize() 는 legacy 인증 경로(initialize)를 타서
  // 신규 콘솔에서 발급한 Client ID 로는 401 이 난다.
  // FlutterNaverMap().init() 이 신규 인증(initializeNcp)을 사용한다.
  await FlutterNaverMap().init(
    clientId: Env.naverMapClientId,
    onAuthFailed: (e) => debugPrint('지도 인증 실패: $e'),
  );
  _initialized = true;
}

Widget buildMap({
  required double lat,
  required double lng,
  required List<MapPin> pins,
  required int zoom,
  void Function(String id)? onPinTap,
}) {
  if (!Env.hasMapKey) {
    return _fallback('지도 키가 설정되지 않았습니다');
  }
  return _MobileMap(
    lat: lat,
    lng: lng,
    pins: pins,
    zoom: zoom,
    onPinTap: onPinTap,
  );
}

Widget _fallback(String msg) => Container(
  color: T.paper,
  alignment: Alignment.center,
  child: Text(
    msg,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontFamilyFallback: T.kr,
      fontSize: 13,
      color: T.mute,
    ),
  ),
);

class _MobileMap extends StatefulWidget {
  const _MobileMap({
    required this.lat,
    required this.lng,
    required this.pins,
    required this.zoom,
    this.onPinTap,
  });

  final double lat;
  final double lng;
  final List<MapPin> pins;
  final int zoom;
  final void Function(String id)? onPinTap;

  @override
  State<_MobileMap> createState() => _MobileMapState();
}

class _MobileMapState extends State<_MobileMap> {
  late final Future<void> _init = _ensureInit();

  /// '#RRGGBB' 를 Color 로. JS 구현과 색 정의를 공유하기 위한 변환이다.
  Color _color(String hex) =>
      Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));

  /// 판정 등급 색을 그대로 보여주는 마커 아이콘을 만든다.
  ///
  /// iconTintColor 를 쓰지 않는 이유:
  ///   그 속성은 기본 아이콘 위에 색을 '가산혼합' 한다. 기본 아이콘이
  ///   이미 색을 가지고 있어서, 어떤 색을 넣어도 밝은 쪽으로 몰려
  ///   가능·조건부·불가가 전부 비슷한 색으로 보였다.
  ///   아이콘 자체를 그려서 넘기면 지정한 색이 그대로 나온다.
  Future<NOverlayImage> _pinIcon(
    BuildContext context, {
    required Color color,
    required bool isOrigin,
  }) {
    final size = isOrigin ? 34.0 : 22.0;

    return NOverlayImage.fromWidget(
      context: context,
      // 흰 테두리를 둘러 지도 배경과 겹쳐도 색이 또렷하게 보이도록 한다.
      widget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: isOrigin ? 3.5 : 2.5,
          ),
        ),
      ),
      size: Size(size, size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.hasError) {
          return _fallback('지도를 불러오지 못했습니다');
        }
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: T.paper,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: T.go),
          );
        }
        return NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(widget.lat, widget.lng),
              zoom: widget.zoom.toDouble(),
            ),
            // 좌표를 외부로 보내는 기능은 쓰지 않는다. 지도 표시 전용이다.
            locationButtonEnable: false,
            scaleBarEnable: true,
          ),
          onMapReady: (controller) async {
            for (final p in widget.pins) {
              // 아이콘 생성이 비동기라 위젯이 사라졌는지 매번 확인한다.
              if (!context.mounted) return;

              final icon = await _pinIcon(
                context,
                color: _color(p.color),
                isOrigin: p.isOrigin,
              );

              final marker = NMarker(
                id: p.id,
                position: NLatLng(p.lat, p.lng),
                // 색은 판정 등급, 크기는 기준 장소 여부를 나타낸다.
                icon: icon,
                size: p.isOrigin ? const Size(34, 34) : const Size(22, 22),
              );
              if (widget.onPinTap != null && !p.isOrigin) {
                marker.setOnTapListener((_) => widget.onPinTap!(p.id));
              }
              await controller.addOverlay(marker);
            }
            // 마커가 여러 개면 전부 보이도록 화면을 맞춘다.
            if (widget.pins.length > 1) {
              await controller.updateCamera(
                NCameraUpdate.fitBounds(
                  NLatLngBounds.from([
                    for (final p in widget.pins) NLatLng(p.lat, p.lng),
                  ]),
                  padding: const EdgeInsets.all(40),
                ),
              );
            }
          },
        );
      },
    );
  }
}
