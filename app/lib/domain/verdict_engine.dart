/// 판정 엔진 — 반려동물 프로필과 장소 제약을 대조해 출입 가능 여부를 판정한다.
///
/// 서비스의 핵심. 기능설명서 #헛걸음_방지 항목이 가리키는 코드다.
/// 판정 규칙의 정본은 docs/schema.md 이며, 규칙을 바꿀 때는 문서를 먼저 고친다.
///
/// 뱃지가 답하는 질문은 하나다: "데려가면 들어갈 수 있나?"
///   불가        데려가면 거부당함
///   조건부 가능  준비물이 없으면 거부당할 수 있음
///   가능        그냥 가면 됨
///   정보없음     판단 근거 부족
///
/// 순수 Dart. Flutter 를 import 하지 않으므로 UI 없이 테스트할 수 있다.
library;

import 'models/pet_profile.dart';
import 'models/place_constraint.dart';
import 'models/verdict.dart';

class VerdictEngine {
  const VerdictEngine();

  /// 법정 의무이자 반려인 기본 지참품.
  /// 장소 고유의 제약이 아니므로 등급을 낮추지 않는다.
  /// 실측 632건 중 414건(65.5%)이 목줄만 요구하므로, 이를 조건으로 세면
  /// 대부분이 '조건부 가능'이 되어 뱃지가 변별력을 잃는다.
  ///
  /// 입마개는 맹견 한정 의무이므로 여기 포함하지 않는다. 일반 반려견에게는
  /// 그 장소만의 요구이며, 챙기지 않으면 실제로 입장을 거부당한다.
  /// 배변봉투도 동물보호법상 장소와 무관한 소유자 의무다(실측 372건).
  /// 목줄과 같은 이유로 등급에 반영하지 않는다.
  static const baselineItems = {'목줄', '배변봉투'};

  Verdict judge(PlaceConstraint p, PetProfile pet) {
    final chips = _buildChips(p);
    // 조건부 입마개는 별도 필드로 파싱되어 requiredItems 에 없다.
    // 그대로 두면 칩에는 뜨는데 준비물 목록에는 빠지는 모순이 생긴다.
    // 체중 조건과 견종 조건은 서로 별개이며 각각 프로필로 평가한다.
    final all = <String>{
      ...p.requiredItems,
      if (p.muzzleOverKg != null && pet.weightKg >= p.muzzleOverKg!) '입마개',
      if (p.muzzleIfFierce && pet.isFierce) '입마개',
    };
    final baseline = all.where(baselineItems.contains).toList();
    final extra = all.where((i) => !baselineItems.contains(i)).toList();
    final zoneNote = p.acmpyType == AcmpyType.partialArea
        ? _zoneNoteOf(p.etcInfo)
        : '';

    Verdict make(VerdictLevel level, String reason, {List<String>? items}) =>
        Verdict(
          level: level,
          reason: reason,
          requiredItems: items ?? const [],
          baselineItems: baseline,
          providedItems: p.providedItems,
          chips: chips,
          sourceText: p.sourceText,
          lastModified: p.lastModified,
          confidence: p.confidence,
          zoneNote: zoneNote,
        );

    // ── 판단 근거 없음 ──
    if (!p.hasDetail) {
      return make(VerdictLevel.unknown, '출입 조건 정보가 없습니다');
    }

    // ── 보조견은 법으로 출입 거부가 금지되어 있다 ──
    if (pet.isGuideDog) {
      return make(VerdictLevel.possible, '장애인 보조견은 출입이 보장됩니다');
    }

    // ── 명시적 불가 ──
    if (p.explicitlyDenied) {
      return make(VerdictLevel.impossible, '반려동물 동반이 불가합니다');
    }

    // 유형은 '동반가능'인데 실제로는 안내견만 허용하는 경우.
    // 두 필드를 교차 검증하지 않으면 오판정이 나는 지점이다. (실측 9건)
    if (p.guideDogOnly) {
      return make(VerdictLevel.impossible, '장애인 보조견만 동반 가능합니다');
    }

    if (p.needsInquiry) {
      return make(VerdictLevel.unknown, '전화 문의가 필요합니다');
    }

    // ── 프로필 대조 ──
    if (p.maxWeightKg != null && pet.weightKg > p.maxWeightKg!) {
      return make(
        VerdictLevel.impossible,
        '${_kg(p.maxWeightKg!)}kg 이하만 가능 (${pet.name} ${_kg(pet.weightKg)}kg)',
      );
    }
    if (p.sizeLimit != null && pet.size.rank > p.sizeLimit!.rank) {
      return make(
        VerdictLevel.impossible,
        '${p.sizeLimit!.label}까지만 가능 (${pet.name}은 ${pet.size.label})',
      );
    }
    if (p.fierceExcluded && pet.isFierce) {
      return make(VerdictLevel.impossible, '맹견은 동반이 제한됩니다');
    }

    // ── 준비물이 있으면 조건부 ──
    if (extra.isNotEmpty) {
      final toBring = extra.where((i) => !p.providedItems.contains(i)).toList();
      final label = toBring.isEmpty
          ? '${extra.join('·')} 필요 (현장 비치)'
          : '${toBring.join('·')} 필요';
      return make(VerdictLevel.conditional, label, items: extra);
    }

    // ── 구조화하지 못한 조건이 남아 있으면 조건부 ──
    if (p.weightInEtcOnly) {
      return make(VerdictLevel.conditional, '체중 조건이 있습니다 — 원문 확인');
    }
    if (p.seeEtcInfo) {
      return make(VerdictLevel.conditional, '추가 조건이 있습니다 — 원문 확인');
    }

    if (p.acmpyType == null || p.acmpyType == AcmpyType.unknownValue) {
      return make(VerdictLevel.unknown, '동반 유형이 기재되어 있지 않습니다');
    }

    // ── 가능 ──
    // 일부구역은 입장 거부가 아니라 이용 범위 제한이므로 등급을 낮추지 않는다.
    // 다만 사유 문구에서 구분해야 칩의 '구역 제한'과 모순되지 않는다.
    if (p.acmpyType == AcmpyType.partialArea) {
      return make(VerdictLevel.possible, '동반 가능하나 이용 구역이 제한됩니다');
    }
    if (p.maxWeightKg != null) {
      return make(
        VerdictLevel.possible,
        '${_kg(p.maxWeightKg!)}kg 이하 조건 충족 (${pet.name} ${_kg(pet.weightKg)}kg)',
      );
    }
    if (p.allBreedOk) {
      return make(VerdictLevel.possible, '전 견종 동반 가능합니다');
    }
    return make(VerdictLevel.possible, '별도 제약이 없습니다');
  }

  /// 구역 안내에서 이미 구조화된 조건 줄을 걷어낸다.
  ///
  /// etcAcmpyInfo 에는 "맹견의 경우 입마개 착용 필수" 같은 조건이 섞여 있는데,
  /// 이건 이미 준비물로 뽑아 화면에 표시하고 있다. 원문을 그대로 두면
  /// 준비물에는 입마개가 있는데 안내에는 "맹견의 경우"라고 적혀 있어,
  /// 소형견 보호자가 자기는 해당 없다고 오해할 수 있다.
  ///
  /// 무조건 요구(acmpyNeedMtr)와 조건부 요구(etcAcmpyInfo)가 같은 품목일 때
  /// 특히 위험하다. 실제로 두 필드가 모두 입마개를 요구하는 장소가 있다.
  static String _zoneNoteOf(String etc) {
    const drop = ['입마개', '배변봉투', '배변 봉투', '목줄'];
    final lines = etc
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .where((l) => !drop.any(l.contains))
        .toList();
    return lines.join('\n');
  }

  List<String> _buildChips(PlaceConstraint p) {
    final out = <String>[];
    if (p.acmpyType == AcmpyType.partialArea) out.add('구역 제한');
    if (p.maxWeightKg != null) out.add('${_kg(p.maxWeightKg!)}kg 이하');
    if (p.sizeLimit != null) out.add('${p.sizeLimit!.label}까지');
    if (p.fierceExcluded) out.add('맹견 제외');
    if (p.maxCount != null) out.add('최대 ${p.maxCount}마리');
    if (p.muzzleOverKg != null) out.add('${_kg(p.muzzleOverKg!)}kg↑ 입마개');
    // 이미 무조건 입마개를 요구하는 곳이면 '맹견 입마개' 칩을 붙이지 않는다.
    // 모든 개가 써야 하는데 조건부처럼 보이면, 맹견이 아닌 보호자가
    // 자기는 해당 없다고 오해한다.
    if (p.muzzleIfFierce && !p.requiredItems.contains('입마개')) {
      out.add('맹견 입마개');
    }
    if (p.outdoorOnly) out.add('야외만');
    return out;
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
