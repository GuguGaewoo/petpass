/// 앱 전역 상태.
///
/// 외부 상태관리 패키지를 쓰지 않는다. 화면이 셋이고 상태가 둘(프로필, 장소)
/// 뿐이라 ChangeNotifier 로 충분하며, 의존성이 적을수록 배포가 단순하다.
library;

import 'package:flutter/foundation.dart';

import 'data/place_repository.dart';
import 'domain/models/pet_profile.dart';
import 'domain/models/place_constraint.dart';
import 'domain/models/verdict.dart';
import 'domain/verdict_engine.dart';

class AppState extends ChangeNotifier {
  final _repo = PlaceRepository();
  final _engine = const VerdictEngine();

  List<PlaceConstraint> _places = const [];
  bool _loading = true;
  String? _error;

  /// 프로필은 기기 안에만 둔다. 서버로 보내지 않는다.
  PetProfile? _pet;

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
    _loading = false;
    notifyListeners();
  }

  void setPet(PetProfile p) {
    _pet = p;
    notifyListeners();
  }

  Verdict judge(PlaceConstraint p) => _engine.judge(p, _pet ?? _defaultPet);

  /// 프로필을 아직 안 넣었을 때의 기준. 제약 없는 조회용.
  static final _defaultPet = PetProfile.byWeight('반려동물', 5);
}
