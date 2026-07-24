/// 반려동물 프로필.
///
/// 순수 Dart. Flutter 를 import 하지 않는다.
library;

enum DogSize {
  small('소형견', 1),
  medium('중형견', 2),
  large('대형견', 3);

  const DogSize(this.label, this.rank);

  final String label;

  /// 크기 비교용. 값이 클수록 큰 개.
  final int rank;

  /// 체중으로 크기를 추정한다. 사용자가 직접 고르지 않았을 때의 기본값.
  /// 실측 데이터의 체중 상한이 10kg 에 몰려 있어 그 경계를 기준으로 삼는다.
  static DogSize fromWeight(double kg) {
    if (kg < 10) return DogSize.small;
    if (kg < 25) return DogSize.medium;
    return DogSize.large;
  }
}

class PetProfile {
  const PetProfile({
    required this.name,
    required this.weightKg,
    required this.size,
    this.breed = '',
    this.isFierce = false,
    this.isGuideDog = false,
    this.vaccinated = true,
  });

  /// 체중만 알 때. 크기는 추정한다.
  factory PetProfile.byWeight(String name, double kg) => PetProfile(
        name: name,
        weightKg: kg,
        size: DogSize.fromWeight(kg),
      );

  final String name;
  final double weightKg;
  final DogSize size;
  final String breed;

  /// 맹견 여부. 동물보호법상 맹견 5종 등.
  final bool isFierce;

  /// 장애인 보조견 여부. 보조견은 출입 거부가 법으로 금지되어 있다.
  final bool isGuideDog;

  final bool vaccinated;

  PetProfile copyWith({
    String? name,
    double? weightKg,
    DogSize? size,
    String? breed,
    bool? isFierce,
    bool? isGuideDog,
    bool? vaccinated,
  }) =>
      PetProfile(
        name: name ?? this.name,
        weightKg: weightKg ?? this.weightKg,
        size: size ?? this.size,
        breed: breed ?? this.breed,
        isFierce: isFierce ?? this.isFierce,
        isGuideDog: isGuideDog ?? this.isGuideDog,
        vaccinated: vaccinated ?? this.vaccinated,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight_kg': weightKg,
        'size': size.name,
        'breed': breed,
        'is_fierce': isFierce,
        'is_guide_dog': isGuideDog,
        'vaccinated': vaccinated,
      };

  static PetProfile fromJson(Map<String, dynamic> j) => PetProfile(
        name: j['name'] as String? ?? '',
        weightKg: (j['weight_kg'] as num?)?.toDouble() ?? 0,
        size: DogSize.values.firstWhere(
          (e) => e.name == j['size'],
          orElse: () => DogSize.fromWeight((j['weight_kg'] as num?)?.toDouble() ?? 0),
        ),
        breed: j['breed'] as String? ?? '',
        isFierce: j['is_fierce'] as bool? ?? false,
        isGuideDog: j['is_guide_dog'] as bool? ?? false,
        vaccinated: j['vaccinated'] as bool? ?? true,
      );
}
