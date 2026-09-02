/// 판정 결과.
///
/// 순수 Dart. Flutter 를 import 하지 않는다.
library;

enum VerdictLevel {
  /// 그냥 가면 된다
  possible('가능'),

  /// 준비물이 없으면 거부당할 수 있다
  conditional('조건부 가능'),

  /// 데려가면 거부당한다
  impossible('불가'),

  /// 판단 근거가 부족하다
  unknown('정보없음');

  const VerdictLevel(this.label);
  final String label;
}

class Verdict {
  const Verdict({
    required this.level,
    required this.reason,
    this.requiredItems = const [],
    this.baselineItems = const [],
    this.providedItems = const [],
    this.chips = const [],
    this.sourceText = const {},
    this.lastModified,
    this.confidence = 0,
    this.zoneNote = '',
    this.zoneSummary = '',
  });

  final VerdictLevel level;

  /// 판정 사유 한 줄. 뱃지 옆에 표시한다.
  final String reason;

  /// 이 장소에서 추가로 필요한 준비물. 등급을 결정한 항목들.
  final List<String> requiredItems;

  /// 목줄처럼 어디서나 기본으로 챙기는 것. 표시는 하되 등급에 반영하지 않는다.
  final List<String> baselineItems;

  /// 현장에 비치되어 있어 따로 챙기지 않아도 되는 품목.
  final List<String> providedItems;

  /// 등급과 별개로 카드에 붙이는 부가 정보 태그.
  final List<String> chips;

  /// 판정 근거 원문. 화면에 반드시 노출한다.
  final Map<String, String> sourceText;

  /// 공공데이터 최종수정일. 화면에 반드시 노출한다.
  final DateTime? lastModified;

  /// 0.0~1.0. 낮으면 원문 확인을 강하게 유도한다.
  final double confidence;

  /// 일부구역인 경우 그 상세가 담긴 자연어 원문.
  final String zoneNote;

  /// 동반 불가 구역 요약 한 줄. 유형을 특정하지 못하면 빈 문자열이고,
  /// 그때는 zoneNote(원문)만 보여준다.
  final String zoneSummary;

  bool get needsSourceCheck => confidence < 0.5 || zoneNote.isNotEmpty;

  /// 사용자가 실제로 챙겨야 할 것 (비치품 제외)
  List<String> get itemsToBring =>
      requiredItems.where((i) => !providedItems.contains(i)).toList();
}
