/// 앱 전역 상태.
///
/// 외부 상태관리 패키지를 쓰지 않는다. 화면 수가 적고 상태가 단순해
/// ChangeNotifier 로 충분하며, 의존성이 적을수록 배포가 단순하다.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/place_repository.dart';
import 'data/report_repository.dart';
import 'domain/models/neighbor.dart';
import 'domain/models/pet_profile.dart';
import 'domain/models/place_constraint.dart';
import 'domain/models/verdict.dart';
import 'domain/nearby_recommender.dart';
import 'domain/verdict_engine.dart';

class AppState extends ChangeNotifier {
  static const _savedKey = 'saved_place_ids';

  final _repo = PlaceRepository();
  final _reports = ReportRepository();
  final _engine = const VerdictEngine();
  final _recommender = const NearbyRecommender();

  List<PlaceConstraint> _places = const [];
  bool _loading = true;
  String? _error;

  /// 프로필은 기기 안에만 두고, 앱을 닫으면 사라진다.
  ///
  /// 저장하지 않는 이유:
  ///   한 가정에 여러 마리가 있거나 남의 반려동물을 대신 확인하는 경우가 있어
  ///   프로필 하나를 자동 저장하면 오히려 틀린 기준으로 판정하게 된다.
  ///   제대로 하려면 다중 프로필(목록·전환·삭제)이 필요하므로
  ///   확장 기능으로 미룬다.
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
    // 제보 저장소는 부가 기능이다. 실패해도 앱은 정상 동작한다.
    await _reports.init();

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

  // ── 현장 제보 (F-10) ──────────────────────────────────
  /// 제보 기능을 쓸 수 있는가. 거짓이면 화면에서 버튼을 감춘다.
  bool get canReport => _reports.isAvailable;

  Future<bool> submitReport({
    required PlaceConstraint place,
    required ReportKind kind,
    String body = '',
  }) => _reports.submit(
    contentId: place.contentId,
    placeTitle: place.title,
    kind: kind,
    body: body,
  );

  /// 장소별 제보 집계. 실패하면 null 이며 화면은 표시하지 않는다.
  Future<ReportSummary?> reportSummaryOf(String contentId) =>
      _reports.summaryOf(contentId);

  /// 프로필을 아직 안 넣었을 때의 기준. 제약 없는 조회용.
  static final _defaultPet = PetProfile.byWeight('반려동물', 5);
}
