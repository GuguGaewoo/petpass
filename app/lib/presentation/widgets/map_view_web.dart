/// 웹용 지도 — 네이버 지도 JS v3.
///
/// flutter_naver_map 은 웹을 지원하지 않아 JS SDK 를 직접 쓴다.
/// 지도 API 호출은 web/naver_map.js 에 두고 여기서는 함수 두 개만 부른다.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/env.dart';
import '../../core/tokens.dart';
import 'map_view.dart';

@JS('petpassMap.load')
external JSPromise<JSAny?> _jsLoad(String keyId);

@JS('petpassMap.render')
external void _jsRender(
  String elId,
  double lat,
  double lng,
  int zoom,
  String pinsJson,
  JSFunction? onTap,
);

int _seq = 0;

Widget buildMap({
  required double lat,
  required double lng,
  required List<MapPin> pins,
  required int zoom,
  void Function(String id)? onPinTap,
}) {
  if (!Env.hasMapKey) {
    // 키가 없어도 앱이 죽지 않아야 한다.
    return _fallback('지도 키가 설정되지 않았습니다');
  }
  return _WebMap(
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

class _WebMap extends StatefulWidget {
  const _WebMap({
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
  State<_WebMap> createState() => _WebMapState();
}

class _WebMapState extends State<_WebMap> {
  late final String _elId = 'petpass-map-${_seq++}';
  late final String _viewType = 'petpass-map-view-$_elId';
  String? _error;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = _elId;
      div.className = 'petpass-map';
      return div;
    });
    _init();
  }

  Future<void> _init() async {
    try {
      await _jsLoad(Env.naverMapClientId).toDart;
      if (!mounted) {
        return;
      }
      // 플랫폼 뷰가 DOM 에 붙은 뒤에 그려야 한다.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) {
        return;
      }
      final json = jsonEncode([
        for (final p in widget.pins)
          {
            'id': p.id,
            'lat': p.lat,
            'lng': p.lng,
            'title': p.title,
            'color': p.color,
            'origin': p.isOrigin,
          },
      ]);
      _jsRender(
        _elId,
        widget.lat,
        widget.lng,
        widget.zoom,
        json,
        widget.onPinTap == null
            ? null
            : ((JSString id) => widget.onPinTap!(id.toDart)).toJS,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = '지도를 불러오지 못했습니다');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _fallback(_error!);
    }
    return HtmlElementView(viewType: _viewType);
  }
}
