/// 주변 추천 화면 — "이런 곳도 함께 가면 좋아요"
///
/// 추천 로직과 지도/마커 동작은 그대로 유지하고 PetPass 시안의
/// 아이보리·라벤더·둥근 카드·의미형 아이콘만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../../domain/models/neighbor.dart';
import '../../domain/models/place_constraint.dart';
import '../../domain/models/verdict.dart';
import '../../domain/nearby_recommender.dart';
import '../widgets/map_view.dart';
import '../widgets/neighbor_sheet.dart';
import '../widgets/verdict_badge.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.state, required this.place});

  final AppState state;
  final PlaceConstraint place;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  late final Future<Nearby> _future = widget.state.recommendNearby(
    widget.place,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FutureBuilder<Nearby>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Column(
                    children: [
                      _topBar(),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: T.brand),
                        ),
                      ),
                    ],
                  );
                }
                if (snap.hasError) {
                  return _message('주변 정보를 불러오지 못했습니다.');
                }
                final n = snap.data!;
                if (n.isEmpty) {
                  return _message(
                    '주변에 추천할 만한 곳을 찾지 못했습니다.\n'
                    '반려동물 동반 정보가 확인된 곳이 없습니다.',
                  );
                }
                return _body(n);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
          color: T.inkSoft,
        ),
        const Spacer(),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: T.brandSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pets_rounded, size: 18, color: T.brand),
        ),
      ],
    ),
  );

  Widget _message(String text) => Column(
    children: [
      _topBar(),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: T.brandSoft,
                  child: Icon(
                    Icons.pets_rounded,
                    size: 34,
                    color: T.brand,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 14,
                    color: T.inkSoft,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _body(Nearby n) {
    final pet = widget.state.pet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        _topBar(),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.place.title} 주변',
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: T.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '이런 곳도 함께 가면 좋아요'
                    '${pet == null ? '' : ' · ${pet.name} 기준'}',
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 12.5,
                      color: T.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.place.lat != null && widget.place.lng != null) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(T.rCard),
              boxShadow: T.softShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 260,
              child: MapView(
                lat: widget.place.lat!,
                lng: widget.place.lng!,
                pins: _pins(n),
                onPinTap: (id) => _openById(id, n),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.location_on_rounded, size: 14, color: T.brand),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  '큰 물방울이 현재 보고 있는 장소입니다 · 색은 판정 등급',
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 11,
                    color: T.mute,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (n.itemsToBring.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle(Icons.backpack_outlined, '함께 챙길 것'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final i in n.itemsToBring)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: T.brandMist,
                    borderRadius: BorderRadius.circular(T.rPill),
                    border: Border.all(color: T.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pets_rounded,
                        size: 13,
                        color: T.brand,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        i,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: T.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        for (final sec in n.sections) ...[
          const SizedBox(height: 26),
          _sectionTitle(_sectionIcon(sec.group.title), sec.group.title),
          if (sec.group.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 10),
              child: Text(
                sec.group.note,
                style: const TextStyle(
                  fontFamilyFallback: T.kr,
                  fontSize: 11.5,
                  color: T.mute,
                  height: 1.45,
                ),
              ),
            )
          else
            const SizedBox(height: 10),
          for (final p in sec.places) ...[
            _NearbyCard(place: p, onTap: () => _open(p.neighbor)),
            const SizedBox(height: T.gapCard),
          ],
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: T.brandMist,
            borderRadius: BorderRadius.circular(T.r),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: T.brand),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '추천은 공공데이터를 기준으로 자동 구성되었습니다. '
                  '동반 정보가 확인되지 않은 곳은 방문 전 현장 확인을 권장합니다.',
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 11.5,
                    color: T.inkSoft,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<MapPin> _pins(Nearby n) {
    final out = <MapPin>[
      MapPin(
        id: widget.place.contentId,
        lat: widget.place.lat!,
        lng: widget.place.lng!,
        title: widget.place.title,
        color: '#8B72C8',
        isOrigin: true,
      ),
    ];
    for (final sec in n.sections) {
      for (final p in sec.places) {
        out.add(
          MapPin(
            id: p.neighbor.contentId,
            lat: p.neighbor.lat,
            lng: p.neighbor.lng,
            title: p.neighbor.title,
            color: switch (p.verdict?.level) {
              VerdictLevel.possible => '#628F66',
              VerdictLevel.conditional => '#B88236',
              VerdictLevel.impossible => '#BD6962',
              VerdictLevel.unknown => '#817985',
              null => '#A69EAA',
            },
          ),
        );
      }
    }
    return out;
  }

  void _openById(String id, Nearby n) {
    for (final sec in n.sections) {
      for (final p in sec.places) {
        if (p.neighbor.contentId == id) {
          _open(p.neighbor);
          return;
        }
      }
    }
  }

  void _open(Neighbor n) =>
      showNeighborSheet(context, state: widget.state, neighbor: n);

  Widget _sectionTitle(IconData icon, String label) => Row(
    children: [
      Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: T.brandSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: T.brandDeep),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          fontFamilyFallback: T.kr,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: T.ink,
        ),
      ),
    ],
  );

  IconData _sectionIcon(String label) {
    if (label.contains('먹') || label.contains('식') || label.contains('카페')) {
      return Icons.restaurant_outlined;
    }
    if (label.contains('숙') || label.contains('쉬')) {
      return Icons.bed_outlined;
    }
    if (label.contains('산책') || label.contains('공원')) {
      return Icons.park_outlined;
    }
    if (label.contains('관광') || label.contains('볼')) {
      return Icons.landscape_outlined;
    }
    return Icons.place_outlined;
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.place, required this.onTap});

  final NearbyPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = place.neighbor;
    final v = place.verdict;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(T.rCard),
        boxShadow: T.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(T.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: T.brandMist,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _kindIcon(n.kind.label),
                    size: 23,
                    color: T.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: T.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: T.paper,
                              borderRadius: BorderRadius.circular(T.rPill),
                            ),
                            child: Text(
                              n.distanceLabel,
                              style: T.mono.copyWith(
                                fontSize: 10.5,
                                color: T.mute,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (n.kind.label.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          n.kind.label,
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 11.5,
                            color: T.mute,
                          ),
                        ),
                      ],
                      if (v != null) ...[
                        const SizedBox(height: 9),
                        VerdictBadge(v.level),
                        const SizedBox(height: 7),
                        Text(
                          v.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 12.5,
                            color: verdictColors(v.level).fg,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: T.lineStrong,
                  ),
                ),
              ],
            ),
          ),
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
    return Icons.location_on_outlined;
  }
}
