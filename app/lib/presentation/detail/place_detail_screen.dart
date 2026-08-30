/// 판정 상세 — 이 앱의 결론이 나오는 화면.
///
/// 장소를 직접 받지 않고 contentId 로 AppState 에서 찾아 쓴다.
/// 화면을 연 뒤 배경에서 실시간 확인이 끝나면 그 결과가 여기에
/// 자동으로 반영되게 하기 위함이다.
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
    required this.contentId,
    required this.fallback,
  });

  final AppState state;

  /// 표시할 장소의 식별자. 실제 값은 AppState 에서 찾는다.
  final String contentId;

  /// 목록에 없을 때 쓸 값.
  /// 실시간 조회로 받은 장소가 아직 목록에 반영되기 전일 수 있다.
  final PlaceConstraint fallback;

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

  static String _pinColor(VerdictLevel l) => switch (l) {
    VerdictLevel.possible => '#628F66',
    VerdictLevel.conditional => '#B88236',
    VerdictLevel.impossible => '#BD6962',
    VerdictLevel.unknown => '#817985',
  };

  @override
  Widget build(BuildContext context) {
    // AppState 가 바뀔 때마다 다시 그린다.
    // 배경에서 진행되는 실시간 확인 결과가 여기에 반영된다.
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    // 목록에 최신값이 있으면 그것을, 없으면 넘겨받은 값을 쓴다.
    final place = state.placeOf(contentId) ?? fallback;
    final refreshing = state.isRefreshing(contentId);

    final v = state.judge(place);
    final pet = state.pet;
    final c = verdictColors(v.level);

    return Scaffold(
      backgroundColor: T.paper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _Header(state: state, place: place, refreshing: refreshing),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(T.rCard),
                    border: Border.all(color: T.line),
                    boxShadow: T.softShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
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
                            const SizedBox(height: 13),
                            Text(
                              v.reason,
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.fg,
                                height: 1.5,
                              ),
                            ),
                            if (pet != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.pets_rounded,
                                    size: 14,
                                    color: c.fg.withValues(alpha: .75),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${pet.name} · ${pet.weightKg.toStringAsFixed(1)}kg · ${pet.size.label}'
                                      '${pet.isFierce ? ' · 맹견' : ''}'
                                      '${pet.isGuideDog ? ' · 보조견' : ''} 기준',
                                      style: TextStyle(
                                        fontFamilyFallback: T.kr,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: c.fg.withValues(alpha: .75),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (v.chips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [for (final x in v.chips) InfoChip(x)],
                          ),
                        ),
                      if (v.itemsToBring.isNotEmpty ||
                          v.baselineItems.isNotEmpty ||
                          v.requiredItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(Icons.backpack_outlined, '챙길 것'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final i in v.itemsToBring)
                                    _bringChip(i, emphasized: true),
                                  for (final i in v.baselineItems)
                                    _bringChip(i, note: '기본'),
                                  for (final i in v.requiredItems.where(
                                    (e) => !v.itemsToBring.contains(e),
                                  ))
                                    _bringChip(i, note: '현장 비치'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (v.zoneNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                          child: _InfoBox(
                            icon: Icons.map_outlined,
                            title: '이용 구역 안내',
                            text: v.zoneNote,
                            background: T.brandMist,
                            iconColor: T.brand,
                          ),
                        ),
                      if (place.riskNotes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: _InfoBox(
                            icon: Icons.warning_amber_rounded,
                            title: '주의',
                            text: place.riskNotes,
                            background: T.holdBg,
                            iconColor: T.hold,
                          ),
                        ),
                      if (place.facilities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: _InfoBox(
                            icon: Icons.home_work_outlined,
                            title: '보유 시설',
                            text: place.facilities.join(', '),
                            background: T.paper,
                            iconColor: T.inkSoft,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            colorScheme: Theme.of(
                              context,
                            ).colorScheme.copyWith(primary: T.brand),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              childrenPadding: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              leading: const Icon(
                                Icons.description_outlined,
                                size: 19,
                                color: T.brand,
                              ),
                              title: const Text(
                                '판정 근거 원문',
                                style: TextStyle(
                                  fontFamilyFallback: T.kr,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: T.ink,
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
                                            style: const TextStyle(
                                              fontFamilyFallback: T.kr,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: T.brandDeep,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            e.value,
                                            style: const TextStyle(
                                              fontFamilyFallback: T.kr,
                                              fontSize: 13.5,
                                              color: T.inkSoft,
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
                          color: T.brandMist,
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
                              '출처 공공 관광데이터 · 방문 전 현장 확인을 권장합니다',
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
              if (place.lat != null && place.lng != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(T.rCard),
                      boxShadow: T.softShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
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
              if (place.overview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: T.card,
                      borderRadius: BorderRadius.circular(T.rCard),
                      border: Border.all(color: T.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.menu_book_outlined, '장소 소개'),
                        const SizedBox(height: 10),
                        _Overview(text: place.overview),
                      ],
                    ),
                  ),
                ),
              if (place.homepage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: InkWell(
                    onTap: () => _openUrl(place.homepage),
                    borderRadius: BorderRadius.circular(T.rPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: T.card,
                        borderRadius: BorderRadius.circular(T.rPill),
                        border: Border.all(color: T.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            size: 18,
                            color: T.brand,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              place.homepage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: T.brandDeep,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: T.brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NearbyScreen(state: state, place: place),
                      ),
                    ),
                    icon: const Icon(Icons.pets_rounded, size: 20),
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rPill),
                      ),
                    ),
                  ),
                ),
              ),
              if (state.canReport)
                _ReportLine(state: state, contentId: place.contentId),
              if (state.canReport)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          showReportSheet(context, state: state, place: place),
                      icon: const Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: T.brand,
                      ),
                      label: const Text(
                        '정보가 실제와 다른가요?',
                        style: TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: T.brandDeep,
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

  static Widget _sectionTitle(IconData icon, String label) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: T.brandMist,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: T.brand),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          fontFamilyFallback: T.kr,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: T.ink,
        ),
      ),
    ],
  );

  Widget _bringChip(String name, {bool emphasized = false, String? note}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized ? T.brandSoft : T.paper,
        borderRadius: BorderRadius.circular(T.rPill),
        border: Border.all(color: emphasized ? T.brand : T.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            emphasized ? Icons.pets_rounded : Icons.check_rounded,
            size: 14,
            color: emphasized ? T.brandDeep : T.inkSoft,
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: emphasized ? T.brandDeep : T.inkSoft,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 5),
            Text(
              note,
              style: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 10.5,
                color: T.mute,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.place,
    required this.refreshing,
  });

  final AppState state;
  final PlaceConstraint place;

  /// 배경에서 최신 조건을 확인하는 중인가.
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final withImage = P.canShowTourImage && place.image.isNotEmpty;

    if (!withImage) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(context, onImage: false),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
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
                    const SizedBox(height: 6),
                    Text(
                      '${place.contentType} · ${place.address}',
                      style: const TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 12.5,
                        color: T.mute,
                        height: 1.5,
                      ),
                    ),
                    // 이미지가 없으면 올려둘 자리가 없으므로 제목 아래에 둔다.
                    if (refreshing) ...[
                      const SizedBox(height: 12),
                      const _RefreshingChip(onImage: false),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 292,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            place.image,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: T.brandMist),
            loadingBuilder: (ctx, child, p) =>
                p == null ? child : const ColoredBox(color: T.brandMist),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66332D3D),
                  Color(0x12332D3D),
                  Color(0xD9332D3D),
                ],
                stops: [0, .42, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _bar(context, onImage: true),
            ),
          ),
          // 배경에서 최신 조건을 확인하는 동안만 보인다.
          // 이미지 위 어두운 그라데이션과 겹치므로 흰 글씨로 둔다.
          if (refreshing) const Center(child: _RefreshingChip()),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: .84),
                    height: 1.45,
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
            icon: Icon(Icons.arrow_back_rounded, size: 21, color: fg),
          ),
        ),
        const Spacer(),
        ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final on = state.isSaved(place.contentId);
            return _circle(
              onImage: onImage,
              child: IconButton(
                onPressed: () => state.toggleSaved(place.contentId),
                icon: Icon(
                  on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 22,
                  color: on ? T.brand : fg,
                ),
                tooltip: on ? '저장 해제' : '저장',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _circle({required bool onImage, required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onImage ? Colors.white.withValues(alpha: .20) : T.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: onImage ? Colors.white.withValues(alpha: .22) : T.line,
        ),
      ),
      child: child,
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.title,
    required this.text,
    required this.background,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(T.r),
        border: Border.all(color: T.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: T.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 13.5,
                    color: T.inkSoft,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                      fontWeight: FontWeight.w700,
                      color: T.brandDeep,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: T.brandDeep,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

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
              color: caution ? T.holdBg : T.brandMist,
              borderRadius: BorderRadius.circular(T.r),
              border: Border.all(color: T.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  caution ? Icons.info_outline : Icons.people_outline,
                  size: 17,
                  color: caution ? T.hold : T.brand,
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

/// 배경에서 최신 조건을 확인하는 동안 보여주는 표시.
///
/// 화면은 이미 열려 있고 기존 데이터로 정상 동작하는 상태다. 이 표시는
/// "잠깐 기다리라"가 아니라 "더 최신인지 확인하고 있다"는 안내다.
/// 그래서 화면을 가리거나 조작을 막지 않는다.
class _RefreshingChip extends StatelessWidget {
  const _RefreshingChip({this.onImage = true});

  /// 이미지 위에 얹는가. 배경에 따라 색을 달리해야 읽힌다.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final fg = onImage ? Colors.white : T.inkSoft;

    return DecoratedBox(
      decoration: BoxDecoration(
        // 이미지 위에서는 반투명 검정, 흰 배경에서는 연한 브랜드색.
        color: onImage ? const Color(0x99332D3D) : T.brandMist,
        borderRadius: BorderRadius.circular(T.rPill),
        border: onImage ? null : Border.all(color: T.brandSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              '최신 정보 확인 중',
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
