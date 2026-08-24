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

@JS('petpassMap.destroy')
external void _jsDestroy(String elId);

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

/// 뷰 타입은 한 번만 등록한다.
///
/// registerViewFactory 로 등록한 타입은 해제할 방법이 없다.
/// 화면을 열 때마다 새 타입을 등록하면 그만큼 쌓이고,
/// 콘솔에 Platform View 경고가 계속 늘어난다.
///
/// 대신 팩토리가 매번 새 div 를 만들고 그 id 를 파라미터로 받는다.
const _viewType = 'petpass-map-view';
bool _registered = false;

void _registerOnce() {
  if (_registered) {
    return;
  }
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (
    int id, {
    Object? params,
  }) {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.id = (params as Map?)?['elId'] as String? ?? 'petpass-map-$id';
    div.className = 'petpass-map';
    return div;
  });
}

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _registerOnce();
    _init();
  }

  Future<void> _init() async {
    try {
      await _jsLoad(Env.naverMapClientId).toDart;
      if (!mounted) {
        return;
      }
      // 플랫폼 뷰가 DOM 에 붙은 뒤에 그려야 한다.
      //
      // 고정 지연으로는 부족하다. 상세 화면처럼 지도가 스크롤 아래에 있으면
      // Flutter 가 뷰를 늦게 붙여, 지정한 시각에 요소가 아직 없다.
      // JS 쪽 render 는 요소가 없으면 조용히 빠져나가므로 지도가 비어 보인다.
      final ok = await _waitForElement(_elId);
      if (!ok || !mounted) {
        return;
      }
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

  /// 요소가 DOM 에 나타날 때까지 짧게 기다린다.
  /// 최대 3초. 그 안에 안 나타나면 화면에 없는 것으로 본다.
  Future<bool> _waitForElement(String id) async {
    for (var i = 0; i < 60; i++) {
      if (web.document.getElementById(id) != null) {
        await Future<void>.delayed(const Duration(milliseconds: 32));
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) {
        return false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    // 지도 인스턴스와 DOM 노드를 함께 치운다.
    // 상세 화면을 여러 번 열면 플랫폼 뷰가 쌓여 메모리를 먹는다.
    _jsDestroy(_elId);
    web.document.getElementById(_elId)?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _fallback(_error!);
    }
    return HtmlElementView(
      viewType: _viewType,
      creationParams: {'elId': _elId},
    );
  }
}
