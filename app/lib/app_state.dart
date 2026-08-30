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
    // 제보 저장소가 Supabase 를 초기화한다. 장소 목록도 이제 Supabase 에서
    // 읽으므로 반드시 _repo.load() 보다 먼저 와야 한다. 순서가 바뀌면
    // Supabase.instance 가 준비되지 않아 매번 에셋으로 폴백한다.
    // 실패해도 예외를 내보내지 않으며, 그때는 에셋으로 폴백한다.
    await _reports.init();

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

  /// 지금 실시간 확인 중인 장소들의 contentId.
  ///
  /// 상세화면이 "최신 정보 확인 중" 표시를 띄울지 판단하는 데 쓴다.
  /// 여러 장소를 빠르게 오갈 수 있으므로 단일 플래그가 아닌 집합이다.
  final Set<String> _refreshing = {};

  bool isRefreshing(String contentId) => _refreshing.contains(contentId);

  /// 장소 하나를 관광 Open API 로 다시 확인하고 그 결과를 반영한다.
  ///
  /// 상세화면을 연 뒤 배경에서 호출한다. 화면 진입을 막지 않으므로
  /// 서버가 잠들어 있어도 사용자는 기다리지 않는다.
  ///
  /// 받아온 값은 목록에도 반영해 같은 세션 안에서는 저장 목록·주변
  /// 추천도 최신 조건으로 판정된다.
  ///
  /// 실패하면 넘겨받은 값을 그대로 돌려주므로 호출하는 쪽에서 예외를
  /// 처리할 필요가 없다.
  Future<PlaceConstraint> refreshPlace(PlaceConstraint current) async {
    // 이미 확인 중이면 중복 호출하지 않는다.
    if (_refreshing.contains(current.contentId)) return current;

    _refreshing.add(current.contentId);
    notifyListeners();

    try {
      final fresh = await _repo.loadLatest(current);

      // 내용이 같으면 목록을 건드리지 않는다.
      if (identical(fresh, current)) return current;

      final i = _places.indexWhere((p) => p.contentId == fresh.contentId);
      if (i >= 0) {
        final next = List<PlaceConstraint>.from(_places);
        next[i] = fresh;
        _places = next;

        // 목록이 바뀌었으므로 contentId 인덱스를 다시 만들게 한다.
        _byId = null;
      }

      return fresh;
    } finally {
      // 성공하든 실패하든 표시는 반드시 걷는다.
      _refreshing.remove(current.contentId);
      notifyListeners();
    }
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
