/// 장소별 반려동물 출입 제약.
///
/// pipeline/normalize.py 가 생성하는 구조화 스키마와 1:1 대응한다.
/// 필드를 바꿀 때는 docs/schema.md 를 먼저 고치고 양쪽을 함께 수정할 것.
///
/// 순수 Dart. Flutter 를 import 하지 않는다.
library;

import 'pet_profile.dart';

/// acmpyTypeCd 를 정규화한 값. 실측 결과 2값 + 미기재뿐이다.
enum AcmpyType {
  /// 전구역 동반가능 (291건)
  allArea,

  /// 일부구역 동반가능 (300건) — 입장은 가능하되 이용 범위가 제한된다
  partialArea,

  /// 매핑에 없는 새 값. patterns.py 보강 필요 신호.
  unknownValue;

  static AcmpyType? parse(String? raw) => switch (raw) {
    'all_area' => AcmpyType.allArea,
    'partial_area' => AcmpyType.partialArea,
    'unknown_value' => AcmpyType.unknownValue,
    _ => null,
  };
}

class PlaceConstraint {
  const PlaceConstraint({
    required this.contentId,
    required this.title,
    this.address = '',
    this.contentType = '',
    this.contentTypeId = '',
    this.areaCode = '',
    this.lat,
    this.lng,
    this.tel = '',
    this.image = '',
    this.hasDetail = false,
    this.acmpyType,
    this.guideDogOnly = false,
    this.explicitlyDenied = false,
    this.needsInquiry = false,
    this.allBreedOk = false,
    this.maxWeightKg,
    this.weightInEtcOnly = false,
    this.sizeLimit,
    this.fierceExcluded = false,
    this.muzzleOverKg,
    this.maxCount,
    this.requiredItems = const [],
    this.freeUse = false,
    this.seeEtcInfo = false,
    this.providedItems = const [],
    this.rentalItems = const [],
    this.facilities = const [],
    this.extraFee = false,
    this.outdoorOnly = false,
    this.riskNotes = '',
    this.etcInfo = '',
    this.sourceText = const {},
    this.lastModified,
    this.confidence = 0,
  });

  final String contentId;
  final String title;
  final String address;
  final String contentType;
  final String contentTypeId;
  final String areaCode;
  final double? lat;
  final double? lng;
  final String tel;
  final String image;

  final bool hasDetail;
  final AcmpyType? acmpyType;
  final bool guideDogOnly;
  final bool explicitlyDenied;
  final bool needsInquiry;
  final bool allBreedOk;

  /// acmpyPsblCpam 에서 추출한 확정 체중 상한.
  /// etcAcmpyInfo 의 체중은 구역별 예외가 섞여 있어 여기 넣지 않는다.
  final double? maxWeightKg;

  /// 체중 언급이 기타정보에만 있어 확정할 수 없는 경우.
  final bool weightInEtcOnly;

  final DogSize? sizeLimit;
  final bool fierceExcluded;

  /// 'N kg 이상 입마개 필수' 의 N. 체중 상한이 아니다.
  final double? muzzleOverKg;

  final int? maxCount;
  final List<String> requiredItems;
  final bool freeUse;
  final bool seeEtcInfo;
  final List<String> providedItems;
  final List<String> rentalItems;
  final List<String> facilities;
  final bool extraFee;
  final bool outdoorOnly;
  final String riskNotes;
  final String etcInfo;

  /// 판정 근거 원문. 결과 화면에 반드시 노출한다.
  final Map<String, String> sourceText;

  /// 공공데이터 최종수정일. 결과 화면에 반드시 노출한다.
  final DateTime? lastModified;

  final double confidence;

  static DogSize? _parseSize(String? raw) => switch (raw) {
    'small' => DogSize.small,
    'medium' => DogSize.medium,
    'large' => DogSize.large,
    _ => null,
  };

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory PlaceConstraint.fromJson(Map<String, dynamic> j) => PlaceConstraint(
    contentId: j['content_id']?.toString() ?? '',
    title: j['title'] as String? ?? '',
    address: j['address'] as String? ?? '',
    contentType: j['content_type'] as String? ?? '',
    contentTypeId: j['content_type_id'] as String? ?? '',
    areaCode: j['area_code'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    tel: j['tel'] as String? ?? '',
    image: j['image'] as String? ?? '',
    hasDetail: j['has_detail'] as bool? ?? false,
    acmpyType: AcmpyType.parse(j['acmpy_type'] as String?),
    guideDogOnly: j['guide_dog_only'] as bool? ?? false,
    explicitlyDenied: j['explicitly_denied'] as bool? ?? false,
    needsInquiry: j['needs_inquiry'] as bool? ?? false,
    allBreedOk: j['all_breed_ok'] as bool? ?? false,
    maxWeightKg: (j['max_weight_kg'] as num?)?.toDouble(),
    weightInEtcOnly: j['weight_in_etc_only'] as bool? ?? false,
    sizeLimit: _parseSize(j['size_limit'] as String?),
    fierceExcluded: j['fierce_excluded'] as bool? ?? false,
    muzzleOverKg: (j['muzzle_over_kg'] as num?)?.toDouble(),
    maxCount: (j['max_count'] as num?)?.toInt(),
    requiredItems: _strList(j['required_items']),
    freeUse: j['free_use'] as bool? ?? false,
    seeEtcInfo: j['see_etc_info'] as bool? ?? false,
    providedItems: _strList(j['provided_items']),
    rentalItems: _strList(j['rental_items']),
    facilities: _strList(j['facilities']),
    extraFee: j['extra_fee'] as bool? ?? false,
    outdoorOnly: j['outdoor_only'] as bool? ?? false,
    riskNotes: j['risk_notes'] as String? ?? '',
    etcInfo: j['etc_info'] as String? ?? '',
    sourceText:
        (j['source_text'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        ) ??
        const {},
    lastModified: j['last_modified'] == null
        ? null
        : DateTime.tryParse(j['last_modified'] as String),
    confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
  );
}
