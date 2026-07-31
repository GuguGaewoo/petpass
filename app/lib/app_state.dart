/// 앱 전역 상태.
///
/// 외부 상태관리 패키지를 쓰지 않는다. 화면 수가 적고 상태가 단순해
/// ChangeNotifier 로 충분하며, 의존성이 적을수록 배포가 단순하다.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/place_repository.dart';
import 'domain/models/neighbor.dart';
import 'domain/models/pet_profile.dart';
import 'domain/models/place_constraint.dart';
import 'domain/models/verdict.dart';
import 'domain/nearby_recommender.dart';
import 'domain/verdict_engine.dart';

class AppState extends ChangeNotifier {
  static const _savedKey = 'saved_place_ids';

  final _repo = PlaceRepository();
  final _engine = const VerdictEngine();
  final _recommender = const NearbyRecommender();

  List<PlaceConstraint> _places = const [];
  bool _loading = true;
  String? _error;

  /// 프로필은 기기 안에만 둔다. 서버로 보내지 않는다.
  PetProfile? _pet;

  /// 저장한 장소. 프로필과 같은 원칙으로 기기 안에만 둔다.
  final Set<String> _saved = {};
  SharedPreferences? _prefs;

  List<PlaceConstraint> get places => _places;
  bool get loading => _loading;
  String? get error => _error;
  PetProfile? get pet => _pet;
  String get sourceLabel => _repo.sourceLabel;

  Future<void> init() async {
    try {
      _places = await _repo.load();
      _error = null;
    } catch (e) {
      _error = '장소 데이터를 불러오지 못했습니다. ($e)';
    }
    // 저장 목록은 실패해도 앱이 동작해야 한다. 핵심 기능이 아니다.
    try {
      _prefs = await SharedPreferences.getInstance();
      _saved.addAll(_prefs?.getStringList(_savedKey) ?? const []);
    } catch (_) {
      // 무시
    }
    _loading = false;
    notifyListeners();
  }

  void setPet(PetProfile p) {
    _pet = p;
    notifyListeners();
  }

  Verdict judge(PlaceConstraint p) => _engine.judge(p, _pet ?? _defaultPet);

  // ── 저장 ────────────────────────────────────────────────
  int get savedCount => _saved.length;

  bool isSaved(String contentId) => _saved.contains(contentId);

  /// 저장 목록. 원본 순서가 아니라 저장한 순서를 따르지 않고
  /// places 순서를 그대로 쓴다. 판정 결과와 나란히 보기 위함이다.
  List<PlaceConstraint> get savedPlaces =>
      _places.where((p) => _saved.contains(p.contentId)).toList();

  void toggleSaved(String contentId) {
    if (!_saved.remove(contentId)) {
      _saved.add(contentId);
    }
    _prefs?.setStringList(_savedKey, _saved.toList());
    notifyListeners();
  }

  // ── 주변 ────────────────────────────────────────────────
  /// contentId -> 장소. 주변 추천에서 이웃을 판정할 때 쓴다.
  /// 632건이라 한 번 만들어 두는 편이 매번 순회하는 것보다 싸다.
  Map<String, PlaceConstraint>? _byId;
  Map<String, PlaceConstraint> get _index =>
      _byId ??= {for (final p in _places) p.contentId: p};

  /// contentId 로 장소를 찾는다. 없으면 null.
  PlaceConstraint? placeOf(String contentId) => _index[contentId];

  /// 주변 장소를 읽는다. 첫 호출에서만 3.7MB 를 파싱한다.
  Future<List<Neighbor>> neighborsOf(PlaceConstraint p) =>
      _repo.loadNeighbors(p.contentId);

  /// 주변 추천을 만든다.
  ///
  /// 이웃 목록은 배치가 미리 계산해 둔 것이므로 실행 중 API 호출이 없다.
  /// 규칙 기반이라 같은 입력이면 항상 같은 결과가 나온다.
  Future<Nearby> recommendNearby(PlaceConstraint p) async {
    final ns = await neighborsOf(p);
    return _recommender.recommend(
      neighbors: ns,
      placeById: _index,
      pet: _pet ?? _defaultPet,
    );
  }

  /// 프로필을 아직 안 넣었을 때의 기준. 제약 없는 조회용.
  static final _defaultPet = PetProfile.byWeight('반려동물', 5);
}
