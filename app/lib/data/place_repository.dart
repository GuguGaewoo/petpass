/// 장소 데이터 로더.
///
/// 관광 Open API 를 앱에서 직접 호출하지 않는다. 인증키가 빌드 산출물에
/// 들어가고 브라우저 CORS 에도 막히기 때문이다. 대신 두 경로를 쓴다.
///
///   전체 목록  Supabase (배치가 매일 Open API 로 동기화해 둔 것)
///   상세 진입  PetPass 백엔드 → 관광 Open API 실시간 재확인
///
/// 두 경로가 모두 막혀도 앱은 동작한다. 목록은 빌드에 포함된
/// assets/places.json 으로, 상세는 이미 읽어 둔 값으로 폴백한다.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../domain/models/neighbor.dart';
import '../domain/models/place_constraint.dart';

class PlaceRepository {
  static const _assetPath = 'assets/places.json';
  static const _neighborPath = 'assets/neighbors.json';

  /// 화면에 표기하는 출처. 기관명을 쓰지 않는다(공모전 규정).
  static const _sourceLabel = '공공 관광데이터';

  /// 목록 조회 상한. 현재 632건이라 넉넉하다.
  /// Supabase 는 지정하지 않으면 1000건에서 잘리므로 명시해 둔다.
  static const _listLimit = 2000;

  /// 실시간 상세조회 제한시간.
  ///
  /// 서버가 잠들어 있으면 깨우는 데 1분 가까이 걸릴 수 있는데,
  /// 그만큼 기다리게 하는 것보다 기존 데이터로 바로 여는 편이 낫다.
  static const _liveTimeout = Duration(seconds: 8);

  List<PlaceConstraint>? _cache;
  String _source = '';

  String get sourceLabel => _source;

  /// 전체 장소를 읽는다.
  ///
  /// Supabase 를 먼저 시도하고, 실패하거나 비어 있으면 빌드에 포함된
  /// JSON 을 쓴다. 반환 타입이 예전과 같으므로 호출하는 쪽은 어느
  /// 경로로 읽었는지 알 필요가 없다.
  Future<List<PlaceConstraint>> load() async {
    if (_cache != null) return _cache!;

    final remote = await _loadFromSupabase();
    if (remote != null && remote.isNotEmpty) {
      _source = _sourceLabel;
      _cache = remote;
      return remote;
    }

    return _loadFromAsset();
  }

  /// Supabase 에서 읽는다. 쓸 수 없으면 null 을 돌려준다.
  ///
  /// 예외를 밖으로 내보내지 않는다. 여기서 실패하는 것은 정상 시나리오
  /// (키 미설정, 네트워크 장애)이고, 그때는 에셋으로 넘어가면 된다.
  Future<List<PlaceConstraint>?> _loadFromSupabase() async {
    if (!Env.hasReportBackend) return null;

    try {
      final rows = await Supabase.instance.client
          .from('places')
          .select()
          .eq('is_active', true)
          .limit(_listLimit);

      return [
        for (final row in rows)
          PlaceConstraint.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (_) {
      return null;
    }
  }

  /// 빌드에 포함된 JSON 에서 읽는다. 최후의 폴백이다.
  Future<List<PlaceConstraint>> _loadFromAsset() async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _source = json['source'] as String? ?? _sourceLabel;
    final list = (json['places'] as List)
        .map((e) => PlaceConstraint.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }

  /// 장소 하나를 관광 Open API 로 다시 확인한다.
  ///
  /// 백엔드가 없거나(주소 미설정) 응답하지 않으면 넘겨받은 값을 그대로
  /// 돌려준다. 실패를 예외로 올리지 않는 이유는, 상세화면이 열리지
  /// 않는 것보다 조금 오래된 데이터로라도 열리는 편이 낫기 때문이다.
  Future<PlaceConstraint> loadLatest(PlaceConstraint current) async {
    if (!Env.hasLiveApi) return current;

    try {
      final base = Env.petpassApiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/places/${current.contentId}/latest');

      final res = await http.get(uri).timeout(_liveTimeout);
      if (res.statusCode != 200) return current;

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) return current;

      return PlaceConstraint.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // 서버 중단, 타임아웃, 파싱 실패 모두 같은 처리를 한다.
      return current;
    }
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
