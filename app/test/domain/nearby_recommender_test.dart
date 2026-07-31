/// 주변 추천 유닛 테스트.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:petpass/domain/models/neighbor.dart';
import 'package:petpass/domain/models/pet_profile.dart';
import 'package:petpass/domain/models/place_constraint.dart';
import 'package:petpass/domain/nearby_recommender.dart';

const rec = NearbyRecommender();
final maltese = PetProfile.byWeight('말티즈', 4);

int _seq = 0;

Neighbor nb(PlaceKind kind, {String? id, bool pet = false, int dist = 1000}) {
  final cid = id ?? 'n${_seq++}';
  return Neighbor(
    contentId: cid,
    title: cid,
    contentTypeId: '12',
    lat: 37,
    lng: 127,
    distanceM: dist,
    petData: pet,
    kind: kind,
  );
}

PlaceConstraint pc(
  String cid, {
  String want = 'possible',
  List<String> items = const [],
}) => PlaceConstraint(
  contentId: cid,
  title: cid,
  hasDetail: want != 'nodata',
  acmpyType: AcmpyType.allArea,
  explicitlyDenied: want == 'denied',
  requiredItems: items,
  lastModified: DateTime(2025, 4, 17),
  sourceText: const {'acmpyTypeCd': '전구역 동반가능'},
  confidence: 0.75,
);

List<NearbyPlace> of(Nearby n, NearbyGroup g) =>
    n.sections.where((s) => s.group == g).expand((s) => s.places).toList();

void main() {
  setUp(() => _seq = 0);

  group('섹션 구성', () {
    test('해당 항목이 없으면 섹션이 아예 나타나지 않는다', () {
      // 빈 섹션을 렌더링하면 미완성으로 읽힌다.
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.outdoor)],
        placeById: {},
        pet: maltese,
      );
      expect(n.sections.length, 1);
      expect(n.sections.first.group, NearbyGroup.walk);
    });

    test('이웃이 없으면 빈 결과', () {
      final n = rec.recommend(neighbors: [], placeById: {}, pet: maltese);
      expect(n.isEmpty, isTrue);
    });

    test('숙박은 별도 섹션으로 분리된다', () {
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.lodging), nb(PlaceKind.outdoor)],
        placeById: {},
        pet: maltese,
      );
      expect(of(n, NearbyGroup.lodging).length, 1);
      expect(of(n, NearbyGroup.walk).length, 1);
    });
  });

  group('미확인 식당 배제', () {
    test('동반 정보가 없는 식당은 추천하지 않는다', () {
      // 야외는 가서 확인하면 되지만 식당은 예약하고 갔다가 거절당한다.
      // 거절 비용이 다르므로 같은 기준으로 다루지 않는다.
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.dining), nb(PlaceKind.dining)],
        placeById: {},
        pet: maltese,
      );
      expect(n.isEmpty, isTrue);
    });

    test('동반 확인된 식당은 추천한다', () {
      // 실측 39곳(6%)뿐이지만, 확인된 곳이므로 근거가 있다.
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.dining, id: 'r', pet: true)],
        placeById: {'r': pc('r')},
        pet: maltese,
      );
      expect(of(n, NearbyGroup.confirmed).length, 1);
    });

    test('유형 미상은 동반 정보가 없으면 추천하지 않는다', () {
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.unknown)],
        placeById: {},
        pet: maltese,
      );
      expect(n.isEmpty, isTrue);
    });
  });

  group('판정 반영', () {
    test('가능이 조건부보다 앞에 온다', () {
      final n = rec.recommend(
        neighbors: [
          nb(PlaceKind.outdoor, id: 'cond', pet: true, dist: 100),
          nb(PlaceKind.outdoor, id: 'ok', pet: true, dist: 5000),
        ],
        placeById: {
          'cond': pc('cond', items: ['이동장']),
          'ok': pc('ok'),
        },
        pet: maltese,
      );
      expect(of(n, NearbyGroup.confirmed).first.neighbor.contentId, 'ok');
    });

    test('판정 불가인 곳은 추천하지 않는다', () {
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.outdoor, id: 'no', pet: true)],
        placeById: {'no': pc('no', want: 'denied')},
        pet: maltese,
      );
      expect(n.isEmpty, isTrue);
    });

    test('미확인 야외에는 판정을 붙이지 않는다', () {
      final n = rec.recommend(
        neighbors: [nb(PlaceKind.outdoor)],
        placeById: {},
        pet: maltese,
      );
      expect(of(n, NearbyGroup.walk).first.verdict, isNull);
    });

    test('프로필에 따라 추천이 달라진다', () {
      final heavy = PlaceConstraint(
        contentId: 'w',
        title: 'w',
        hasDetail: true,
        acmpyType: AcmpyType.allArea,
        maxWeightKg: 10,
        lastModified: DateTime(2025, 4, 17),
        sourceText: const {'acmpyTypeCd': '전구역 동반가능'},
        confidence: 0.75,
      );
      List<String> run(PetProfile p) => of(
        rec.recommend(
          neighbors: [nb(PlaceKind.outdoor, id: 'w', pet: true)],
          placeById: {'w': heavy},
          pet: p,
        ),
        NearbyGroup.confirmed,
      ).map((e) => e.neighbor.contentId).toList();

      expect(run(PetProfile.byWeight('말티즈', 4)), ['w']);
      expect(run(PetProfile.byWeight('리트리버', 30)), isEmpty);
    });
  });

  group('준비물', () {
    test('확인된 곳의 준비물이 중복 없이 합쳐진다', () {
      final n = rec.recommend(
        neighbors: [
          nb(PlaceKind.outdoor, id: 'a', pet: true),
          nb(PlaceKind.dining, id: 'b', pet: true),
        ],
        placeById: {
          'a': pc('a', items: ['목줄', '이동장']),
          'b': pc('b', items: ['목줄', '입마개']),
        },
        pet: maltese,
      );
      expect(n.itemsToBring, containsAll(['이동장', '입마개']));
      expect(n.itemsToBring.toSet().length, n.itemsToBring.length);
      expect(n.itemsToBring, isNot(contains('목줄')));
    });
  });
}
