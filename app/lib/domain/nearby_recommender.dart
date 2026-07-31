/// 주변 추천 — "이런 곳도 함께 가면 좋아요"
///
/// 기준 장소 주변의 사전 계산된 이웃 목록에서 함께 갈 만한 곳을 골라
/// 성격별로 묶는다. 실행 중 API 를 호출하지 않는다.
///
/// 왜 시간대 코스가 아니라 추천 목록인가 (전국 632건 실측):
///   - 동반이 확인된 식당이 있는 기준 장소는 39곳(6%)뿐이다.
///     시간대 슬롯을 만들면 94%에서 식사 칸이 빈다. 빈 칸은 미완성으로 읽힌다.
///   - 성격별 묶음은 해당 항목이 없으면 섹션 자체가 나타나지 않는다.
///     채워야 할 자리가 없으므로 실패할 구조가 없다.
///   - "코스"는 "여기서 점심을 드세요"라는 보증에 가깝지만
///     "함께 가면 좋아요"는 제안이다. 근거가 약한 정보에는 후자가 정직하다.
///
/// 미확인 식당을 노출하지 않는 이유:
///   야외 공간은 정보가 없어도 가서 확인하면 되지만, 식당은 예약하고 갔다가
///   문 앞에서 거절당한다. 반려동물을 두고 들어갈 수도 없다.
///   거절 비용이 유형마다 다르므로 같은 기준으로 다루지 않는다.
///
/// 순수 Dart. Flutter 를 import 하지 않으므로 UI 없이 테스트할 수 있다.
library;

import 'models/neighbor.dart';
import 'models/pet_profile.dart';
import 'models/place_constraint.dart';
import 'models/verdict.dart';
import 'verdict_engine.dart';

enum NearbyGroup {
  /// 동반 조건이 공공데이터로 확인된 곳. 판정 뱃지가 붙는다.
  confirmed('함께 가기 좋은 곳', '동반 조건이 확인된 곳입니다'),

  /// 야외 공간. 동반 정보는 없지만 확인 비용이 낮다.
  walk('산책하기 좋은 곳', '야외 공간입니다. 동반 정보는 확인되지 않았습니다'),

  /// 부가 정보
  lodging('근처 숙소', '');

  const NearbyGroup(this.title, this.note);
  final String title;
  final String note;
}

class NearbyPlace {
  const NearbyPlace({required this.neighbor, this.verdict});

  final Neighbor neighbor;

  /// 동반 데이터가 있는 곳만 판정이 붙는다.
  /// null 이면 근거가 없다는 뜻이므로 판정을 표시하지 않는다.
  final Verdict? verdict;

  bool get isConfirmed => verdict != null;
}

class NearbySection {
  const NearbySection({required this.group, required this.places});

  final NearbyGroup group;
  final List<NearbyPlace> places;
}

class Nearby {
  const Nearby({required this.sections, required this.itemsToBring});

  final List<NearbySection> sections;

  /// 확인된 곳들에서 챙겨야 할 것을 합친 목록
  final List<String> itemsToBring;

  bool get isEmpty => sections.isEmpty;

  int get confirmedCount => sections
      .where((s) => s.group == NearbyGroup.confirmed)
      .fold(0, (a, s) => a + s.places.length);
}

class NearbyRecommender {
  const NearbyRecommender({this.engine = const VerdictEngine()});

  final VerdictEngine engine;

  static const maxConfirmed = 8;
  static const maxWalk = 6;
  static const maxLodging = 3;

  Nearby recommend({
    required List<Neighbor> neighbors,
    required Map<String, PlaceConstraint> placeById,
    required PetProfile pet,
  }) {
    final possible = <NearbyPlace>[];
    final conditional = <NearbyPlace>[];
    final walk = <NearbyPlace>[];
    final lodging = <NearbyPlace>[];

    for (final n in neighbors) {
      if (n.kind == PlaceKind.lodging) {
        if (lodging.length < maxLodging) {
          lodging.add(NearbyPlace(neighbor: n));
        }
        continue;
      }

      final p = n.petData ? placeById[n.contentId] : null;
      if (p != null) {
        final v = engine.judge(p, pet);
        switch (v.level) {
          case VerdictLevel.possible:
            possible.add(NearbyPlace(neighbor: n, verdict: v));
          case VerdictLevel.conditional:
            conditional.add(NearbyPlace(neighbor: n, verdict: v));
          case VerdictLevel.unknown:
          case VerdictLevel.impossible:
            // 갈 수 없거나 판단할 수 없는 곳은 추천하지 않는다
            break;
        }
        continue;
      }

      // 여기부터는 동반 데이터가 없는 곳이다.
      // 야외만 받는다. 식당은 거절 비용이 커서 근거 없이 권하지 않는다.
      if (n.kind == PlaceKind.outdoor && walk.length < maxWalk) {
        walk.add(NearbyPlace(neighbor: n));
      }
    }

    // 확인된 곳은 가능 -> 조건부 순. 같은 등급 안에서는 거리순(입력 순서)
    final confirmed = [...possible, ...conditional].take(maxConfirmed).toList();

    final sections = <NearbySection>[
      if (confirmed.isNotEmpty)
        NearbySection(group: NearbyGroup.confirmed, places: confirmed),
      if (walk.isNotEmpty) NearbySection(group: NearbyGroup.walk, places: walk),
      if (lodging.isNotEmpty)
        NearbySection(group: NearbyGroup.lodging, places: lodging),
    ];

    final items = <String>[];
    for (final c in confirmed) {
      for (final i in c.verdict?.itemsToBring ?? const <String>[]) {
        if (!items.contains(i)) {
          items.add(i);
        }
      }
    }

    return Nearby(sections: sections, itemsToBring: items);
  }
}
