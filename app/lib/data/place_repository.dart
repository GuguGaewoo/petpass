/// 장소 데이터 로더.
///
/// TourAPI 를 앱에서 직접 호출하지 않는다. pipeline 배치가 수집·정규화하여
/// assets/places.json 에 넣어두고, 앱은 그것만 읽는다.
///   - 앱 빌드 산출물에 TourAPI 인증키가 들어가지 않는다
///   - 브라우저 CORS 차단이 발생하지 않는다
///   - 외부 서비스가 멈춰도 핵심 기능이 동작한다
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/place_constraint.dart';

class PlaceRepository {
  static const _assetPath = 'assets/places.json';

  List<PlaceConstraint>? _cache;
  String _source = '';

  String get sourceLabel => _source;

  Future<List<PlaceConstraint>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _source = json['source'] as String? ?? '';
    final list = (json['places'] as List)
        .map((e) => PlaceConstraint.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }
}
