/// 판정 상세 — 이 앱의 결론이 나오는 화면.
///
/// 확인증 형식을 취한다. 도장(판정) 아래에 대조 대상(반려동물), 사유,
/// 준비물, 그리고 하단에 근거 원문과 데이터 최종수정일을 작은 글씨로 둔다.
/// 근거와 갱신일을 함께 노출하는 것은 이 서비스의 설계 원칙이다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../../domain/models/place_constraint.dart';
import '../nearby/nearby_screen.dart';
import '../widgets/verdict_badge.dart';

class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({
    super.key,
    required this.state,
    required this.place,
  });

  final AppState state;
  final PlaceConstraint place;

  static const _fieldNames = {
    'acmpyTypeCd': '동반 유형',
    'acmpyPsblCpam': '동반 가능 동물',
    'acmpyNeedMtr': '동반 시 필요사항',
    'relaAcdntRiskMtr': '사고 대비사항',
    'relaPosesFclty': '보유 시설',
    'relaFrnshPrdlst': '비치 품목',
    'relaRntlPrdlst': '대여 품목',
    'relaPurcPrdlst': '구매 품목',
    'etcAcmpyInfo': '기타 동반 정보',
  };

  @override
  Widget build(BuildContext context) {
    final v = state.judge(place);
    final pet = state.pet;
    final c = verdictColors(v.level);

    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: T.inkSoft,
                    ),
                    const Spacer(),
                    // 저장은 기기 안에만 기록한다. 프로필과 같은 원칙이다.
                    ListenableBuilder(
                      listenable: state,
                      builder: (context, _) {
                        final on = state.isSaved(place.contentId);
                        return IconButton(
                          onPressed: () => state.toggleSaved(place.contentId),
                          icon: Icon(
                            on ? Icons.star : Icons.star_border,
                            size: 22,
                            color: on ? T.hold : T.inkSoft,
                          ),
                          tooltip: on ? '저장 해제' : '저장',
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  place.title,
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
                  '${place.contentType} · ${place.address}',
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 13,
                    color: T.inkSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // ── 확인증 ──
                Container(
                  decoration: BoxDecoration(
                    color: T.card,
                    border: Border.all(color: c.fg.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(T.rCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(T.rCard),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VerdictBadge(v.level, large: true),
                            const SizedBox(height: 12),
                            Text(
                              v.reason,
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.fg,
                                height: 1.5,
                              ),
                            ),
                            if (pet != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                '대조 기준  ${pet.name} · ${pet.weightKg.toStringAsFixed(1)}kg · ${pet.size.label}'
                                '${pet.isGuideDog ? ' · 보조견' : ''}',
                                style: T.mono.copyWith(
                                  fontSize: 11.5,
                                  color: c.fg.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (v.chips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [for (final x in v.chips) InfoChip(x)],
                          ),
                        ),

                      // ── 준비물 ──
                      if (v.itemsToBring.isNotEmpty ||
                          v.baselineItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('챙길 것'),
                              for (final i in v.itemsToBring)
                                _item(i, emphasized: true),
                              for (final i in v.baselineItems)
                                _item(i, note: '기본'),
                              for (final i in v.requiredItems.where(
                                (e) => !v.itemsToBring.contains(e),
                              ))
                                _item(i, note: '현장 비치'),
                            ],
                          ),
                        ),

                      // ── 구역 원문 ──
                      if (v.zoneNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: T.paper,
                              border: Border.all(color: T.line),
                              borderRadius: BorderRadius.circular(T.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('이용 구역 안내'),
                                Text(
                                  v.zoneNote,
                                  style: const TextStyle(
                                    fontFamilyFallback: T.kr,
                                    fontSize: 13,
                                    color: T.ink,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (place.riskNotes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('주의'),
                              Text(
                                place.riskNotes,
                                style: const TextStyle(
                                  fontFamilyFallback: T.kr,
                                  fontSize: 13,
                                  color: T.ink,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (place.facilities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('보유 시설'),
                              Text(
                                place.facilities.join(', '),
                                style: const TextStyle(
                                  fontFamilyFallback: T.kr,
                                  fontSize: 13,
                                  color: T.ink,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── 근거 ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: Material(
                            color: Colors
                                .transparent, // 투명이어야 부모 Container 배경색이 보인다
                            child: Material(
                              color: Colors
                                  .transparent, // 투명이어야 바깥 Container 배경색이 보인다
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                title: Text(
                                  '판정 근거 원문',
                                  style: TextStyle(
                                    fontFamilyFallback: T.kr,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: T.inkSoft,
                                  ),
                                ),
                                children: [
                                  for (final e in place.sourceText.entries)
                                    if (e.value.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _fieldNames[e.key] ?? e.key,
                                              style: T.mono.copyWith(
                                                fontSize: 10.5,
                                                color: T.mute,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              e.value,
                                              style: const TextStyle(
                                                fontFamilyFallback: T.kr,
                                                fontSize: 13,
                                                color: T.ink,
                                                height: 1.6,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: T.line)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.lastModified == null
                                  ? '공공데이터 최종수정일 정보 없음'
                                  : '공공데이터 최종수정일  ${_ymd(place.lastModified!)}',
                              style: T.mono.copyWith(
                                fontSize: 11,
                                color: T.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              '출처 한국관광공사 TourAPI · 방문 전 현장 확인을 권장합니다',
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 11,
                                color: T.mute,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NearbyScreen(state: state, place: place),
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text(
                      '주변에 함께 갈 곳 보기',
                      style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: T.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.r),
                      ),
                    ),
                  ),
                ),
                if (place.tel.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '전화  ${place.tel}',
                    style: T.mono.copyWith(fontSize: 13, color: T.ink),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Widget _sectionLabel(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontFamilyFallback: T.kr,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: T.inkSoft,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _item(String name, {bool emphasized = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            emphasized ? Icons.check_box_outline_blank : Icons.check,
            size: 16,
            color: emphasized ? T.ink : T.mute,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 14,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
              color: emphasized ? T.ink : T.inkSoft,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 6),
            Text(
              note,
              style: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 11,
                color: T.mute,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
