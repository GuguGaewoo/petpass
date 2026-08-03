/// 주변 추천 화면 — "이런 곳도 함께 가면 좋아요"
///
/// 성격별 섹션으로 묶어 보여준다. 해당 항목이 없으면 섹션 자체가
/// 나타나지 않으므로 빈 자리가 생기지 않는다.
///
/// 동반 조건이 확인된 곳에만 판정 뱃지를 붙인다.
/// 근거 없이 판정하지 않는다는 원칙을 화면에서도 지킨다.
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
                      _back(),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: T.go),
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

  Widget _back() => Align(
    alignment: Alignment.centerLeft,
    child: IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back, size: 20),
      color: T.inkSoft,
    ),
  );

  Widget _message(String text) => Column(
    children: [
      _back(),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 14,
                color: T.inkSoft,
                height: 1.7,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _body(Nearby n) {
    final pet = widget.state.pet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _back(),
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
        const SizedBox(height: 4),
        Text(
          '이런 곳도 함께 가면 좋아요'
          '${pet == null ? '' : ' · ${pet.name} 기준'}',
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 13,
            color: T.inkSoft,
          ),
        ),

        // 지도. 기준 장소와 추천 장소를 함께 찍어 거리를 눈으로 알 수 있게 한다.
        if (widget.place.lat != null && widget.place.lng != null) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(T.rCard),
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
          const SizedBox(height: 6),
          const Text(
            '큰 물방울이 현재 보고 있는 장소입니다 · 색은 판정 등급',
            style: TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 11.5,
              color: T.mute,
            ),
          ),
        ],

        if (n.itemsToBring.isNotEmpty) ...[
          const SizedBox(height: 18),
          _label('함께 챙길 것'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final i in n.itemsToBring) InfoChip(i)],
          ),
        ],

        for (final sec in n.sections) ...[
          const SizedBox(height: 24),
          _label(sec.group.title),
          if (sec.group.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                sec.group.note,
                style: const TextStyle(
                  fontFamilyFallback: T.kr,
                  fontSize: 12,
                  color: T.mute,
                  height: 1.4,
                ),
              ),
            ),
          for (final p in sec.places) ...[
            _NearbyCard(place: p, onTap: () => _open(p.neighbor)),
            const SizedBox(height: 8),
          ],
        ],

        const SizedBox(height: 20),
        const Text(
          '추천은 공공데이터를 기준으로 자동 구성되었습니다. '
          '동반 정보가 확인되지 않은 곳은 방문 전 현장 확인을 권장합니다.',
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 11.5,
            color: T.mute,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// 기준 장소 + 추천 장소를 마커로 만든다.
  List<MapPin> _pins(Nearby n) {
    final out = <MapPin>[
      MapPin(
        id: widget.place.contentId,
        lat: widget.place.lat!,
        lng: widget.place.lng!,
        title: widget.place.title,
        color: '#171B18',
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
            // 판정이 있는 곳만 등급 색을 쓴다.
            // 근거 없는 곳에 색을 부여하면 판정한 것처럼 읽힌다.
            color: switch (p.verdict?.level) {
              VerdictLevel.possible => '#1F6F4A',
              VerdictLevel.conditional => '#9A6209',
              VerdictLevel.impossible => '#A32F2A',
              VerdictLevel.unknown => '#6E7671',
              null => '#9BA39D',
            },
          ),
        );
      }
    }
    return out;
  }

  /// 마커를 눌렀을 때 해당 장소의 시트를 띄운다.
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

  /// 간단 정보를 바텀시트로 띄운다.
  ///
  /// 동반 데이터가 없는 곳은 공공데이터에 개요가 없어 보여줄 설명이 없다.
  /// 가진 것(이름·주소·거리·유형·이미지)만 보여주고, 확인된 곳은
  /// 시트에서 판정 상세로 넘어가게 한다.
  void _open(Neighbor n) =>
      showNeighborSheet(context, state: widget.state, neighbor: n);

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontFamilyFallback: T.kr,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: T.ink,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.place, required this.onTap});

  final NearbyPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = place.neighbor;
    final v = place.verdict;

    return Material(
      color: T.card,
      borderRadius: BorderRadius.circular(T.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.rCard),
          ),
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
                        fontWeight: FontWeight.w700,
                        color: T.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    n.distanceLabel,
                    style: T.mono.copyWith(fontSize: 11.5, color: T.mute),
                  ),
                ],
              ),
              if (v != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    VerdictBadge(v.level),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        v.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 12.5,
                          color: verdictColors(v.level).fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (n.kind.label.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  n.kind.label,
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 12,
                    color: T.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
