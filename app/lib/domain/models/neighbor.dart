/// 주변 장소.
///
/// 배치가 위치기반 조회로 미리 계산해 assets/neighbors.json 에 넣어둔 값이다.
/// 앱 실행 중에는 API 를 호출하지 않으므로 오프라인에서도 동작한다.
///
/// 순수 Dart. Flutter 를 import 하지 않는다.
library;

/// 장소 성격. 판정이 아니라 일정 배치 우선순위를 가르는 힌트다.
///
/// 반려동물 동반 데이터가 없는 곳에 "야외이므로 동반 가능"이라고 단정하면
/// 근거 없는 판정이 된다. 4단계 뱃지는 petData 가 true 인 곳에만 붙이고,
/// 이 값은 정렬과 라벨에만 쓴다.
enum PlaceKind {
  /// 공원·산책로·해변 등. 동반 가능성이 상대적으로 높다
  outdoor('야외'),

  /// 음식점
  dining('음식점'),

  /// 숙박
  lodging('숙박'),

  /// 유형을 판별하지 못함. 제보(F-10)로 보강할 대상이다
  unknown('');

  const PlaceKind(this.label);
  final String label;

  static PlaceKind parse(String? raw) => switch (raw) {
    'outdoor' => PlaceKind.outdoor,
    'dining' => PlaceKind.dining,
    'lodging' => PlaceKind.lodging,
    _ => PlaceKind.unknown,
  };
}

class Neighbor {
  const Neighbor({
    required this.contentId,
    required this.title,
    required this.contentTypeId,
    required this.lat,
    required this.lng,
    this.address = '',
    this.image = '',
    this.distanceM = 0,
    this.petData = false,
    this.kind = PlaceKind.unknown,
  });

  final String contentId;
  final String title;
  final String contentTypeId;
  final double lat;
  final double lng;
  final String address;
  final String image;

  /// 기준 장소로부터의 거리(m)
  final int distanceM;

  /// 반려동물 동반 데이터가 있는 곳인가.
  /// true 면 판정 엔진을 돌려 뱃지를 붙일 수 있다.
  final bool petData;

  final PlaceKind kind;

  /// 화면 표시용 거리
  String get distanceLabel => distanceM < 1000
      ? '${distanceM}m'
      : '${(distanceM / 1000).toStringAsFixed(1)}km';

  static Neighbor fromJson(Map<String, dynamic> j) => Neighbor(
    contentId: j['content_id']?.toString() ?? '',
    title: j['title'] as String? ?? '',
    contentTypeId: j['content_type_id']?.toString() ?? '',
    lat: (j['lat'] as num?)?.toDouble() ?? 0,
    lng: (j['lng'] as num?)?.toDouble() ?? 0,
    address: j['address'] as String? ?? '',
    image: j['image'] as String? ?? '',
    distanceM: (j['distance_m'] as num?)?.toInt() ?? 0,
    petData: j['pet_data'] as bool? ?? false,
    kind: PlaceKind.parse(j['place_kind'] as String?),
  );
}
