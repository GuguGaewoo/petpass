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

import '../domain/models/neighbor.dart';
import '../domain/models/place_constraint.dart';

class PlaceRepository {
  static const _assetPath = 'assets/places.json';
  static const _neighborPath = 'assets/neighbors.json';

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

  Map<String, List<Neighbor>>? _neighbors;

  /// 주변 장소를 읽는다.
  ///
  /// 지연 로딩이다. 이 파일은 3.7MB 로 places.json 의 6배가 넘어,
  /// 앱 시작 시점에 읽으면 웹 첫 화면이 눈에 띄게 느려진다.
  /// 사용자가 주변 탐색이나 일정 추천에 들어올 때만 읽는다.
  ///
  /// 한 번 읽으면 메모리에 유지한다. 일정 기능에 진입한 사용자는
  /// 여러 장소를 비교하므로 매번 다시 파싱하는 편이 더 비싸다.
  Future<List<Neighbor>> loadNeighbors(String contentId) async {
    await _ensureNeighbors();
    return _neighbors![contentId] ?? const [];
  }

  /// 주변 데이터가 준비되었는지. 화면에서 버튼 노출 판단에 쓴다.
  bool get neighborsReady => _neighbors != null;

  Future<void> _ensureNeighbors() async {
    if (_neighbors != null) return;
    final raw = await rootBundle.loadString(_neighborPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final src = json['neighbors'] as Map<String, dynamic>;
    _neighbors = {
      for (final e in src.entries)
        e.key: [
          for (final n in (e.value as List))
            Neighbor.fromJson(n as Map<String, dynamic>),
        ],
    };
  }
}
