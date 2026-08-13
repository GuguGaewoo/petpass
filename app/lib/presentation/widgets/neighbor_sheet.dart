/// 주변 장소 간단 정보.
///
/// 기존 상세 이동/데이터 노출 기준은 유지하고 PetPass 시안의
/// 아이보리·라벤더·둥근 카드·발바닥 CTA만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/platform.dart';
import '../../core/tokens.dart';
import '../../domain/models/neighbor.dart';
import '../detail/place_detail_screen.dart';
import 'petpass_decor.dart';

Future<void> showNeighborSheet(
  BuildContext context, {
  required AppState state,
  required Neighbor neighbor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: T.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _Sheet(state: state, neighbor: neighbor),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.state, required this.neighbor});

  final AppState state;
  final Neighbor neighbor;

  @override
  Widget build(BuildContext context) {
    final n = neighbor;
    final place = state.placeOf(n.contentId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: T.lineStrong,
                  borderRadius: BorderRadius.circular(T.rPill),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (P.canShowTourImage && n.image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(T.rCard),
                child: Stack(
                  children: [
                    Image.network(
                      n.image,
                      height: 164,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(T.rPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: T.brand,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              n.distanceLabel,
                              style: T.mono.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: T.brandDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: T.brandSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _kindIcon(n.kind.label),
                    size: 21,
                    color: T.brand,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: T.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (n.kind.label.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: T.brandMist,
                                borderRadius: BorderRadius.circular(T.rPill),
                              ),
                              child: Text(
                                n.kind.label,
                                style: const TextStyle(
                                  fontFamilyFallback: T.kr,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: T.brandDeep,
                                ),
                              ),
                            ),
                          if (!(P.canShowTourImage && n.image.isNotEmpty))
                            Text(
                              '${n.distanceLabel} 거리',
                              style: T.mono.copyWith(
                                fontSize: 11,
                                color: T.mute,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (n.address.isNotEmpty) ...[
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: T.paper,
                  borderRadius: BorderRadius.circular(T.r),
                  border: Border.all(color: T.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 17,
                      color: T.brand,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        n.address,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 13,
                          color: T.inkSoft,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (place != null)
              PetPassPrimaryButton(
                label: '동반 조건 자세히 보기',
                height: 54,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaceDetailScreen(state: state, place: place),
                    ),
                  );
                },
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: T.brandMist,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: T.brand,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이 곳은 공공데이터에 반려동물 동반 정보가 없습니다.\n'
                        '방문 전 현장 확인을 권장합니다.',
                        style: TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 12.5,
                          color: T.inkSoft,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _kindIcon(String label) {
    if (label.contains('카페') || label.contains('음식') || label.contains('식')) {
      return Icons.restaurant_outlined;
    }
    if (label.contains('숙박') || label.contains('숙소')) {
      return Icons.bed_outlined;
    }
    if (label.contains('쇼핑')) return Icons.shopping_bag_outlined;
    if (label.contains('문화')) return Icons.museum_outlined;
    if (label.contains('관광')) return Icons.landscape_outlined;
    if (label.contains('레포츠')) return Icons.directions_run_rounded;
    return Icons.location_on_outlined;
  }
}
