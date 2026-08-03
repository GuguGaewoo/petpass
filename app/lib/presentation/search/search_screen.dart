/// 장소 목록. 프로필과 대조한 판정을 함께 보여준다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/area_codes.dart';
import '../../core/tokens.dart';
import '../../domain/models/place_constraint.dart';
import '../../domain/models/verdict.dart';
import '../detail/place_detail_screen.dart';
import '../saved/saved_screen.dart';
import '../widgets/verdict_badge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  String? _area;
  String? _type;
  bool _onlyPossible = false;

  /// 지역은 17개라 모두 펼치면 좁은 화면에서 목록을 밀어낸다.
  /// 기본은 접고, 선택된 것만 보여준다.
  bool _areaOpen = false;

  static const _types = ['관광지', '숙박', '음식점', '레포츠', '쇼핑', '문화시설'];

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pet = s.pet;

    final list = s.places.where((p) {
      if (_area != null && p.areaCode != _area) {
        return false;
      }
      if (_type != null && p.contentType != _type) {
        return false;
      }
      if (_query.isNotEmpty &&
          !p.title.contains(_query) &&
          !p.address.contains(_query)) {
        return false;
      }
      return true;
    }).toList();

    final judged = [for (final p in list) (place: p, verdict: s.judge(p))];
    if (_onlyPossible) {
      judged.removeWhere((e) => e.verdict.level != VerdictLevel.possible);
    }
    judged.sort(
      (a, b) => a.verdict.level.index.compareTo(b.verdict.level.index),
    );

    final counts = <VerdictLevel, int>{};
    for (final e in judged) {
      counts[e.verdict.level] = (counts[e.verdict.level] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 20),
                        color: T.inkSoft,
                      ),
                      Expanded(
                        child: Text(
                          pet == null
                              ? '장소 찾기'
                              : '${pet.name} · ${pet.weightKg.toStringAsFixed(1)}kg · ${pet.size.label}'
                                    '${pet.isFierce ? ' · 맹견' : ''}'
                                    '${pet.isGuideDog ? ' · 보조견' : ''}',
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: s,
                        builder: (context, _) {
                          final n = s.savedCount;
                          return TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SavedScreen(state: s),
                              ),
                            ),
                            icon: Icon(
                              n > 0 ? Icons.star : Icons.star_border,
                              size: 18,
                              color: n > 0 ? T.hold : T.inkSoft,
                            ),
                            label: Text(
                              n > 0 ? '$n' : '',
                              style: T.mono.copyWith(
                                fontSize: 12.5,
                                color: T.inkSoft,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: '장소 이름이나 주소로 검색',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: T.mute,
                      ),
                      filled: true,
                      fillColor: T.card,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(T.r),
                        borderSide: const BorderSide(color: T.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(T.r),
                        borderSide: const BorderSide(color: T.line),
                      ),
                    ),
                  ),
                ),

                // 필터.
                //
                // 가로 스크롤은 뒤에 무엇이 있는지 보이지 않아 사용자가 놓친다.
                // Wrap 으로 두면 화면 폭에 맞춰 알아서 접히고 전체가 한눈에 들어온다.
                // 성격이 다른 셋을 덩어리로 나눈다: 판정 / 유형 / 지역.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _filter(
                        '가능한 곳만',
                        _onlyPossible,
                        () => setState(() => _onlyPossible = !_onlyPossible),
                      ),
                      const SizedBox(height: 14),

                      _groupLabel('유형'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in _types)
                            _filter(
                              t,
                              _type == t,
                              () =>
                                  setState(() => _type = _type == t ? null : t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _groupLabel('지역', trailing: _areaToggle()),
                      if (_areaOpen)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in areaNames.entries)
                              _filter(
                                e.value,
                                _area == e.key,
                                () => setState(
                                  () => _area = _area == e.key ? null : e.key,
                                ),
                              ),
                          ],
                        )
                      else if (_area != null)
                        // 접어도 선택된 지역은 남겨 현재 필터 상태를 드러낸다
                        _filter(
                          areaNames[_area] ?? '',
                          true,
                          () => setState(() => _area = null),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        '${judged.length}곳',
                        style: T.mono.copyWith(fontSize: 12, color: T.inkSoft),
                      ),
                      const SizedBox(width: 10),
                      for (final l in VerdictLevel.values)
                        if ((counts[l] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${l.label} ${counts[l]}',
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 11.5,
                                color: verdictColors(l).fg,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                Expanded(
                  child: judged.isEmpty
                      ? const Center(
                          child: Text(
                            '조건에 맞는 곳이 없습니다. 필터를 줄여보세요.',
                            style: TextStyle(
                              fontFamilyFallback: T.kr,
                              fontSize: 14,
                              color: T.inkSoft,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: judged.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = judged[i];
                            return _PlaceCard(
                              place: e.place,
                              verdict: e.verdict,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlaceDetailScreen(
                                    state: widget.state,
                                    place: e.place,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 필터 묶음 제목
  Widget _groupLabel(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: T.mute,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
  }

  Widget _areaToggle() {
    return GestureDetector(
      onTap: () => setState(() => _areaOpen = !_areaOpen),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _areaOpen ? '접기' : '전체 보기',
            style: const TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 11.5,
              color: T.inkSoft,
            ),
          ),
          Icon(
            _areaOpen ? Icons.expand_less : Icons.expand_more,
            size: 15,
            color: T.inkSoft,
          ),
        ],
      ),
    );
  }

  Widget _filter(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Wrap 이 간격을 담당하므로 margin 을 두지 않는다.
        // 대신 높이가 고정되지 않으므로 세로 패딩을 준다.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? T.ink : T.card,
          border: Border.all(color: on ? T.ink : T.line),
          borderRadius: BorderRadius.circular(T.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 13,
            color: on ? Colors.white : T.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.verdict,
    required this.onTap,
  });

  final PlaceConstraint place;
  final Verdict verdict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = verdictColors(verdict.level);

    return Material(
      color: T.card,
      borderRadius: BorderRadius.circular(T.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진이 카드의 절반을 차지한다.
            // 반려동물 여행 서비스에서 글자만 있는 목록은 밋밋하다.
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (place.image.isNotEmpty)
                    Image.network(
                      place.image,
                      fit: BoxFit.cover,
                      // 이미지가 없거나 막혀도 레이아웃이 무너지지 않게 한다
                      errorBuilder: (_, _, _) => const _NoImage(),
                      loadingBuilder: (ctx, child, p) =>
                          p == null ? child : const _NoImage(),
                    )
                  else
                    const _NoImage(),

                  // 아래쪽을 어둡게 깔아 흰 글씨가 읽히게 한다
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC0F231A)],
                      ),
                    ),
                  ),

                  Positioned(
                    left: 14,
                    top: 14,
                    child: VerdictBadge(verdict.level),
                  ),

                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${place.contentType} \u00b7 ${_shortAddr(place.address)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: T.caption,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verdict.reason,
                    style: TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: T.body,
                      color: c.fg,
                      height: 1.4,
                    ),
                  ),
                  if (verdict.chips.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final x in verdict.chips) InfoChip(x)],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 전체 주소는 카드에서 너무 길다. 시도 + 시군구까지만 남긴다.
  static String _shortAddr(String addr) {
    final parts = addr.split(' ');
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : addr;
  }
}

/// 이미지가 없거나 불러오지 못했을 때의 자리.
class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: T.sunken,
    child: Center(child: Icon(Icons.photo_outlined, size: 26, color: T.mute)),
  );
}
