/// 판정 상세 — 이 앱의 결론이 나오는 화면.
///
/// 상단에 사진과 판정을 얹고, 그 아래에 근거를 쌓는다.
/// 판정 사유, 준비물, 근거 원문, 데이터 최종수정일을 함께 노출하는 것이
/// 이 서비스의 설계 원칙이다.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../core/platform.dart';
import '../../core/tokens.dart';
import '../../data/report_repository.dart';
import '../../domain/models/place_constraint.dart';
import '../../domain/models/verdict.dart';
import '../nearby/nearby_screen.dart';
import '../widgets/map_view.dart';
import '../widgets/report_sheet.dart';
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

  /// 판정 등급별 지도 마커 색. 화면 뱃지와 같은 언어를 쓴다.
  static String _pinColor(VerdictLevel l) => switch (l) {
    VerdictLevel.possible => '#0F6E56',
    VerdictLevel.conditional => '#B07A1F',
    VerdictLevel.impossible => '#A85248',
    VerdictLevel.unknown => '#8C857E',
  };

  @override
  Widget build(BuildContext context) {
    final v = state.judge(place);
    final pet = state.pet;
    final c = verdictColors(v.level);

    return Scaffold(
      backgroundColor: T.paper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            // 사진이 화면 최상단까지 닿아야 한다. 좌우 여백은 항목마다 준다.
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _Header(state: state, place: place, verdict: v),

              // ── 확인증 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: T.card,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(T.rCard),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        color: c.bg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VerdictBadge(v.level, large: true),
                            const SizedBox(height: 14),
                            Text(
                              v.reason,
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.fg,
                                height: 1.5,
                              ),
                            ),
                            if (pet != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${pet.name} · ${pet.weightKg.toStringAsFixed(1)}kg · ${pet.size.label}'
                                '${pet.isFierce ? ' · 맹견' : ''}'
                                '${pet.isGuideDog ? ' · 보조견' : ''} 기준',
                                style: T.mono.copyWith(
                                  fontSize: 11.5,
                                  color: c.fg.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (v.chips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
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
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: T.sunken,
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
                                    fontSize: 13.5,
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
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('주의'),
                              Text(
                                place.riskNotes,
                                style: const TextStyle(
                                  fontFamilyFallback: T.kr,
                                  fontSize: 13.5,
                                  color: T.ink,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (place.facilities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('보유 시설'),
                              Text(
                                place.facilities.join(', '),
                                style: const TextStyle(
                                  fontFamilyFallback: T.kr,
                                  fontSize: 13.5,
                                  color: T.ink,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── 근거 원문 ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: Material(
                            // 투명이어야 부모 Container 배경색이 보인다
                            color: Colors.transparent,
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              // 기본값이 center 라 필드명과 원문이 가운데로 몰린다
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              childrenPadding: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              title: const Text(
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
                                        bottom: 12,
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
                                          const SizedBox(height: 3),
                                          Text(
                                            e.value,
                                            style: const TextStyle(
                                              fontFamilyFallback: T.kr,
                                              fontSize: 13.5,
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

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        decoration: const BoxDecoration(
                          color: T.sunken,
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
                            const SizedBox(height: 4),
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
              ),

              // ── 지도 ──
              if (place.lat != null && place.lng != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(T.rCard),
                    child: SizedBox(
                      height: 200,
                      child: MapView(
                        lat: place.lat!,
                        lng: place.lng!,
                        zoom: 15,
                        pins: [
                          MapPin(
                            id: place.contentId,
                            lat: place.lat!,
                            lng: place.lng!,
                            title: place.title,
                            color: _pinColor(v.level),
                            isOrigin: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 장소 개요. 국문 관광정보에서 가져온다(실측 94%).
              // 판정 아래에 두는 이유는 이 앱을 여는 이유가 "갈 수 있나"이기 때문이다.
              // 개요는 그다음에 읽는 보조 정보다.
              if (place.overview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: _Overview(text: place.overview),
                ),

              if (place.homepage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: InkWell(
                    onTap: () => _openUrl(place.homepage),
                    borderRadius: BorderRadius.circular(T.r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.language_outlined,
                            size: 16,
                            color: T.go,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place.homepage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 13,
                                color: T.go,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NearbyScreen(state: state, place: place),
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined, size: 19),
                    label: const Text(
                      '주변에 함께 갈 곳 보기',
                      style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: T.brand,
                      foregroundColor: T.onBrand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rCard),
                      ),
                    ),
                  ),
                ),
              ),

              // 이용자 제보 집계. 공공데이터 판정과 섞지 않고 분리해서 보여준다.
              // 검증되지 않은 정보이므로 판정 카드 안에 넣지 않는다.
              if (state.canReport)
                _ReportLine(state: state, contentId: place.contentId),

              // 제보는 부가 기능이므로 눈에 덜 띄는 형태로 둔다.
              // 저장소를 쓸 수 없으면 아예 노출하지 않는다.
              if (state.canReport)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          showReportSheet(context, state: state, place: place),
                      icon: const Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: T.mute,
                      ),
                      label: const Text(
                        '정보가 실제와 다른가요?',
                        style: TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 13,
                          color: T.mute,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Widget _sectionLabel(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      s,
      style: const TextStyle(
        fontFamilyFallback: T.kr,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: T.mute,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _item(String name, {bool emphasized = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            emphasized ? Icons.check_box_outline_blank : Icons.check,
            size: 17,
            color: emphasized ? T.ink : T.mute,
          ),
          const SizedBox(width: 9),
          Text(
            name,
            style: TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 14.5,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
              color: emphasized ? T.ink : T.inkSoft,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 7),
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

  /// 홈페이지를 브라우저로 연다.
  /// url_launcher 를 쓰지 않고 최소한으로 처리한다.
  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// 상단 헤더.
///
/// 앱에서는 사진 위에 제목을 얹고, 웹에서는 사진 없이 텍스트만 둔다.
/// TourAPI 이미지 서버가 CORS 헤더를 주지 않아 브라우저가 차단하기 때문이다.
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.place,
    required this.verdict,
  });

  final AppState state;
  final PlaceConstraint place;
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final withImage = P.canShowTourImage && place.image.isNotEmpty;

    if (!withImage) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(context, onImage: false),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: const TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: T.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${place.contentType} · ${place.address}',
                      style: const TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 13,
                        color: T.mute,
                        height: 1.5,
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

    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            place.image,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: T.sunken),
            loadingBuilder: (ctx, child, p) =>
                p == null ? child : const ColoredBox(color: T.sunken),
          ),
          // 위아래를 어둡게 깔아 아이콘과 글씨가 읽히게 한다
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x730F231A),
                  Color(0x1A0F231A),
                  Color(0xE60F231A),
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _bar(context, onImage: true),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.title,
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${place.contentType} · ${place.address}',
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, {required bool onImage}) {
    final fg = onImage ? Colors.white : T.inkSoft;
    return Row(
      children: [
        _circle(
          onImage: onImage,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, size: 20, color: fg),
          ),
        ),
        const Spacer(),
        // 저장은 기기 안에만 기록한다. 프로필과 같은 원칙이다.
        ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final on = state.isSaved(place.contentId);
            return _circle(
              onImage: onImage,
              child: IconButton(
                onPressed: () => state.toggleSaved(place.contentId),
                icon: Icon(
                  on ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 23,
                  color: on ? T.hold : fg,
                ),
                tooltip: on ? '저장 해제' : '저장',
              ),
            );
          },
        ),
      ],
    );
  }

  /// 사진 위에서는 아이콘이 배경에 묻히므로 반투명 원을 깐다.
  Widget _circle({required bool onImage, required Widget child}) {
    if (!onImage) {
      return child;
    }
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// 장소 개요. 길면 접어서 보여준다.
///
/// 실측 중앙값이 322자, 최대 1629자다. 전부 펼쳐두면 판정보다
/// 개요가 화면을 더 차지하게 되므로 기본은 4줄로 접는다.
class _Overview extends StatefulWidget {
  const _Overview({required this.text});

  final String text;

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    // 짧은 개요는 접을 이유가 없다
    final short = widget.text.length <= 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: (_open || short) ? null : 4,
          overflow: (_open || short)
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 14,
            color: T.inkSoft,
            height: 1.7,
          ),
        ),
        if (!short)
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _open ? '접기' : '더 보기',
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: T.mute,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: T.mute,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 이용자 제보 집계 한 줄.
///
/// 본문은 보여주지 않는다. 검증되지 않은 텍스트를 그대로 노출하면
/// 잘못된 정보가 퍼지므로, 선택지 집계를 문장으로 만들어 전달한다.
/// 불러오지 못하면 아무것도 그리지 않는다.
class _ReportLine extends StatefulWidget {
  const _ReportLine({required this.state, required this.contentId});

  final AppState state;
  final String contentId;

  @override
  State<_ReportLine> createState() => _ReportLineState();
}

class _ReportLineState extends State<_ReportLine> {
  late final Future<ReportSummary?> _future = widget.state.reportSummaryOf(
    widget.contentId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReportSummary?>(
      future: _future,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null || s.total == 0) {
          return const SizedBox.shrink();
        }
        final caution = s.needsCaution;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: caution ? T.holdBg : T.sunken,
              borderRadius: BorderRadius.circular(T.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  caution ? Icons.info_outline : Icons.people_outline,
                  size: 16,
                  color: caution ? T.hold : T.inkSoft,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    s.line,
                    style: TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 12.5,
                      color: caution ? T.hold : T.inkSoft,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
