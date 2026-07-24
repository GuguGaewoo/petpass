/// 판정 엔진 유닛 테스트.
///
///     cd app && dart test          (또는 flutter test)
///
/// 모든 케이스는 전국 632건 실사에서 실제로 발견된 데이터에 기반한다.
/// 규칙을 손댈 때마다 여기를 돌려 회귀를 막는다.
library;

import 'package:petpass/domain/models/pet_profile.dart';
import 'package:petpass/domain/models/place_constraint.dart';
import 'package:petpass/domain/models/verdict.dart';
import 'package:petpass/domain/verdict_engine.dart';
import 'package:test/test.dart';

const engine = VerdictEngine();

final maltese = PetProfile.byWeight('말티즈', 4);
final cocker = PetProfile.byWeight('코커', 12);
final retriever = PetProfile.byWeight('리트리버', 30);

PlaceConstraint place({
  bool hasDetail = true,
  AcmpyType? type = AcmpyType.allArea,
  bool guideDogOnly = false,
  bool denied = false,
  bool inquiry = false,
  bool allBreed = false,
  double? maxWeight,
  DogSize? sizeLimit,
  bool fierceExcluded = false,
  List<String> items = const [],
  List<String> provided = const [],
  bool weightInEtc = false,
  bool seeEtc = false,
  String etc = '',
}) =>
    PlaceConstraint(
      contentId: '1',
      title: '테스트',
      hasDetail: hasDetail,
      acmpyType: type,
      guideDogOnly: guideDogOnly,
      explicitlyDenied: denied,
      needsInquiry: inquiry,
      allBreedOk: allBreed,
      maxWeightKg: maxWeight,
      sizeLimit: sizeLimit,
      fierceExcluded: fierceExcluded,
      requiredItems: items,
      providedItems: provided,
      weightInEtcOnly: weightInEtc,
      seeEtcInfo: seeEtc,
      etcInfo: etc,
      lastModified: DateTime(2024, 12, 18),
      sourceText: const {'acmpyTypeCd': '전구역 동반가능'},
      confidence: 0.75,
    );

void main() {
  group('불가 판정', () {
    test('안내견 전용 — 유형이 동반가능이어도 일반 반려견은 불가', () {
      // 실측 9건. 두 필드를 교차 검증하지 않으면 오판정이 나는 핵심 케이스.
      final v = engine.judge(place(guideDogOnly: true), maltese);
      expect(v.level, VerdictLevel.impossible);
    });

    test('체중 초과 — 사유에 상한과 실제 체중이 함께 나온다', () {
      final v = engine.judge(place(maxWeight: 10), cocker);
      expect(v.level, VerdictLevel.impossible);
      expect(v.reason, contains('10kg'));
      expect(v.reason, contains('12kg'));
    });

    test('견종 크기 초과', () {
      final v = engine.judge(place(sizeLimit: DogSize.small), retriever);
      expect(v.level, VerdictLevel.impossible);
      expect(v.reason, contains('소형견'));
    });

    test('맹견 제외 — 맹견이 아니면 영향 없음', () {
      expect(engine.judge(place(fierceExcluded: true), maltese).level,
          VerdictLevel.possible);
      final fierce = maltese.copyWith(isFierce: true);
      expect(engine.judge(place(fierceExcluded: true), fierce).level,
          VerdictLevel.impossible);
    });

    test('명시적 동반 불가', () {
      expect(engine.judge(place(denied: true), maltese).level,
          VerdictLevel.impossible);
    });
  });

  group('보조견 예외', () {
    test('보조견은 안내견 전용 장소에서도 가능', () {
      final guide = maltese.copyWith(isGuideDog: true);
      expect(engine.judge(place(guideDogOnly: true), guide).level,
          VerdictLevel.possible);
    });

    test('보조견은 체중 제한도 적용받지 않는다', () {
      // 장애인복지법상 보조견 출입 거부는 금지되어 있다.
      final guide = retriever.copyWith(isGuideDog: true);
      expect(engine.judge(place(maxWeight: 5), guide).level, VerdictLevel.possible);
    });
  });

  group('조건부 가능', () {
    test('목줄만 필요하면 조건부가 아니다', () {
      // 실측 414건(65.5%). 이걸 조건으로 세면 뱃지가 변별력을 잃는다.
      final v = engine.judge(place(items: ['목줄']), maltese);
      expect(v.level, VerdictLevel.possible);
      expect(v.baselineItems, ['목줄']);
      expect(v.requiredItems, isEmpty);
    });

    test('이동장이 필요하면 조건부', () {
      final v = engine.judge(place(items: ['목줄', '이동장']), maltese);
      expect(v.level, VerdictLevel.conditional);
      expect(v.requiredItems, ['이동장']);
      expect(v.baselineItems, ['목줄']);
      expect(v.reason, contains('이동장'));
    });

    test('입마개는 맹견 한정 의무이므로 조건으로 유지', () {
      final v = engine.judge(place(items: ['목줄', '입마개']), maltese);
      expect(v.level, VerdictLevel.conditional);
    });

    test('현장 비치품은 챙길 목록에서 빠진다', () {
      final v = engine.judge(
          place(items: ['이동장'], provided: ['이동장']), maltese);
      expect(v.itemsToBring, isEmpty);
      expect(v.reason, contains('현장 비치'));
    });

    test('체중 조건이 기타정보에만 있으면 원문 확인 유도', () {
      final v = engine.judge(place(weightInEtc: true), maltese);
      expect(v.level, VerdictLevel.conditional);
      expect(v.reason, contains('원문'));
    });
  });

  group('가능 판정', () {
    test('일부구역은 등급을 낮추지 않되 사유에서 구분한다', () {
      // 실측 300건(47.5%). 입장 거부가 아니라 이용 범위 제한이다.
      final v = engine.judge(place(type: AcmpyType.partialArea), maltese);
      expect(v.level, VerdictLevel.possible);
      expect(v.reason, contains('구역'));
      expect(v.chips, contains('구역 제한'));
    });

    test('체중 조건을 통과하면 사유에 충족 사실이 나온다', () {
      final v = engine.judge(place(maxWeight: 10), maltese);
      expect(v.level, VerdictLevel.possible);
      expect(v.reason, contains('충족'));
      expect(v.chips, contains('10kg 이하'));
    });

    test('전 견종 허용', () {
      final v = engine.judge(place(allBreed: true), retriever);
      expect(v.level, VerdictLevel.possible);
    });
  });

  group('정보없음', () {
    test('상세 데이터 없음', () {
      expect(engine.judge(place(hasDetail: false), maltese).level,
          VerdictLevel.unknown);
    });

    test('전화문의 필요', () {
      expect(engine.judge(place(inquiry: true), maltese).level,
          VerdictLevel.unknown);
    });

    test('동반 유형 미기재', () {
      expect(engine.judge(place(type: null), maltese).level, VerdictLevel.unknown);
    });
  });

  group('근거 보존', () {
    test('모든 판정에 원문과 최종수정일이 따라온다', () {
      for (final p in [
        place(guideDogOnly: true),
        place(maxWeight: 10),
        place(items: ['이동장']),
        place(type: AcmpyType.partialArea),
      ]) {
        final v = engine.judge(p, cocker);
        expect(v.sourceText, isNotEmpty, reason: '판정 근거 원문이 유실되면 안 된다');
        expect(v.lastModified, isNotNull, reason: '데이터 신선도를 알 수 없으면 안 된다');
      }
    });

    test('일부구역이면 구역 원문을 함께 전달한다', () {
      final v = engine.judge(
          place(type: AcmpyType.partialArea, etc: '카라반 동반 불가(오토캠핑장만 가능)'),
          maltese);
      expect(v.zoneNote, contains('오토캠핑장'));
      expect(v.needsSourceCheck, isTrue);
    });
  });

  group('프로필별 변별력', () {
    test('같은 장소라도 프로필에 따라 결과가 갈린다', () {
      final p = place(maxWeight: 10);
      expect(engine.judge(p, maltese).level, VerdictLevel.possible);
      expect(engine.judge(p, cocker).level, VerdictLevel.impossible);
      expect(engine.judge(p, retriever).level, VerdictLevel.impossible);
    });

    test('체중으로 크기를 추정한다', () {
      expect(DogSize.fromWeight(4), DogSize.small);
      expect(DogSize.fromWeight(12), DogSize.medium);
      expect(DogSize.fromWeight(30), DogSize.large);
    });
  });
}