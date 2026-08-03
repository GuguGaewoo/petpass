/// 주변 장소 간단 정보.
///
/// 동반 데이터가 없는 곳은 공공데이터에 개요가 없어 보여줄 설명이 없다.
/// 가진 것(이름·주소·거리·유형·이미지)만 정직하게 보여주고,
/// 동반 조건이 확인된 곳은 판정 상세로 넘어갈 수 있게 한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/platform.dart';
import '../../core/tokens.dart';
import '../../domain/models/neighbor.dart';
import '../detail/place_detail_screen.dart';

Future<void> showNeighborSheet(
  BuildContext context, {
  required AppState state,
  required Neighbor neighbor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: T.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: T.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (P.canShowTourImage && n.image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(T.rCard),
                child: Image.network(
                  n.image,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // 이미지 URL 이 무효해도 레이아웃이 무너지지 않게 한다
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            Text(
              n.title,
              style: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: T.ink,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (n.kind.label.isNotEmpty) ...[
                  Text(
                    n.kind.label,
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 12.5,
                      color: T.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${n.distanceLabel} 거리',
                  style: T.mono.copyWith(fontSize: 12, color: T.mute),
                ),
              ],
            ),
            if (n.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                n.address,
                style: const TextStyle(
                  fontFamilyFallback: T.kr,
                  fontSize: 13.5,
                  color: T.ink,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 18),
            if (place != null)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlaceDetailScreen(state: state, place: place),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: T.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(T.r),
                    ),
                  ),
                  child: const Text(
                    '동반 조건 자세히 보기',
                    style: TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: T.paper,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r),
                ),
                child: const Text(
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
    );
  }
}
