/// 장소 목록. 프로필과 대조한 판정을 함께 보여준다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/area_codes.dart';
import '../../core/platform.dart';
import '../../core/tokens.dart';
import '../../domain/models/place_constraint.dart';
import '../../domain/models/verdict.dart';
import '../detail/place_detail_screen.dart';
import '../saved/saved_screen.dart';
import '../widgets/petpass_decor.dart';
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
  bool _areaOpen = false;

  static const _types = ['관광지', '숙박', '음식점', '레포츠', '쇼핑', '문화시설'];

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pet = s.pet;

    final list = s.places.where((p) {
      if (_area != null && p.areaCode != _area) return false;
      if (_type != null && p.contentType != _type) return false;
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
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 21),
                        color: T.inkSoft,
                      ),
                      Expanded(
                        child: Text(
                          pet == null
                              ? '펫패스'
                              : '${pet.name} · ${pet.weightKg.toStringAsFixed(1)}kg · ${pet.size.label}'
                                    '${pet.isFierce ? ' · 맹견' : ''}'
                                    '${pet.isGuideDog ? ' · 보조견' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: T.inkSoft,
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: s,
                        builder: (context, _) {
                          final n = s.savedCount;
                          return InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SavedScreen(state: s),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(T.rPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: n > 0 ? T.brandSoft : T.card,
                                borderRadius: BorderRadius.circular(T.rPill),
                                border: Border.all(
                                  color: n > 0 ? T.brandSoft : T.line,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    n > 0
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: n > 0 ? T.brandDeep : T.inkSoft,
                                  ),
                                  if (n > 0) ...[
                                    const SizedBox(width: 5),
                                    Text(
                                      '$n',
                                      style: T.mono.copyWith(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: T.brandDeep,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '어디를 찾고 있나요?',
                          style: TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: T.ink,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '장소 이름, 주소와 실제 동반 조건을 함께 확인해요.',
                          style: TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 12.5,
                            color: T.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 15,
                      color: T.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: '장소 이름이나 주소로 검색',
                      hintStyle: const TextStyle(
                        fontFamilyFallback: T.kr,
                        color: T.mute,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: T.brand,
                      ),
                      suffixIcon: const Padding(
                        padding: EdgeInsets.all(13),
                        child: PetPassPawIcon(size: 18),
                      ),
                      filled: true,
                      fillColor: T.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(T.rPill),
                        borderSide: const BorderSide(color: T.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(T.rPill),
                        borderSide: const BorderSide(color: T.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(T.rPill),
                        borderSide: const BorderSide(color: T.brand, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: T.card,
                      borderRadius: BorderRadius.circular(T.rCard),
                      border: Border.all(color: T.line),
                      boxShadow: T.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _groupLabel('장소 유형'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in _types)
                              _typeFilter(
                                t,
                                _type == t,
                                () => setState(
                                  () => _type = _type == t ? null : t,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _groupLabel('지역')),
                            _areaToggle(),
                          ],
                        ),
                        if (_areaOpen)
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
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
                          _filter(
                            areaNames[_area] ?? '',
                            true,
                            () => setState(() => _area = null),
                          ),
                        const SizedBox(height: 14),
                        _possibleSwitch(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        '${judged.length}곳',
                        style: T.mono.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: T.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
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
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: judged.isEmpty
                      ? const _EmptyResult()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemCount: judged.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: T.gapCard),
                          itemBuilder: (context, i) {
                            final e = judged[i];
                            return ListenableBuilder(
                              listenable: s,
                              builder: (context, _) {
                                return _PlaceCard(
                                  place: e.place,
                                  verdict: e.verdict,
                                  saved: s.isSaved(e.place.contentId),
                                  onSavedToggle: () =>
                                      s.toggleSaved(e.place.contentId),
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

  Widget _groupLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontFamilyFallback: T.kr,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: T.ink,
      ),
    ),
  );

  Widget _areaToggle() {
    return GestureDetector(
      onTap: () => setState(() => _areaOpen = !_areaOpen),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _areaOpen ? '접기' : '전체 보기',
              style: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: T.brandDeep,
              ),
            ),
            Icon(
              _areaOpen ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: T.brandDeep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeFilter(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: on ? T.brandSoft : T.paper,
          border: Border.all(color: on ? T.brand : T.line),
          borderRadius: BorderRadius.circular(T.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _typeIcon(label),
              size: 15,
              color: on ? T.brandDeep : T.inkSoft,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? T.brandDeep : T.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: on ? T.brandSoft : T.paper,
          border: Border.all(color: on ? T.brand : T.line),
          borderRadius: BorderRadius.circular(T.rPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: on ? T.brandDeep : T.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _possibleSwitch() {
    return InkWell(
      onTap: () => setState(() => _onlyPossible = !_onlyPossible),
      borderRadius: BorderRadius.circular(T.r),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: T.goBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pets_rounded, size: 17, color: T.go),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              '동반 가능한 곳만 보기',
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: T.ink,
              ),
            ),
          ),
          Switch(
            value: _onlyPossible,
            activeThumbColor: T.brand,
            activeTrackColor: T.brandSoft,
            onChanged: (v) => setState(() => _onlyPossible = v),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
    '관광지' => Icons.landscape_outlined,
    '숙박' => Icons.bed_outlined,
    '음식점' => Icons.restaurant_outlined,
    '레포츠' => Icons.directions_run_rounded,
    '쇼핑' => Icons.shopping_bag_outlined,
    '문화시설' => Icons.museum_outlined,
    _ => Icons.place_outlined,
  };
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.verdict,
    required this.saved,
    required this.onSavedToggle,
    required this.onTap,
  });

  final PlaceConstraint place;
  final Verdict verdict;
  final bool saved;
  final VoidCallback onSavedToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = verdictColors(verdict.level);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: saved ? T.brandSoft : T.line),
        boxShadow: T.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(T.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (P.canShowTourImage)
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
                          errorBuilder: (_, _, _) => const _NoImage(),
                          loadingBuilder: (ctx, child, p) =>
                              p == null ? child : const _NoImage(),
                        )
                      else
                        const _NoImage(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xC8332D3D)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: VerdictBadge(verdict.level),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _FavoriteBubble(
                          saved: saved,
                          onPressed: onSavedToggle,
                        ),
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
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${place.contentType} · ${_shortAddr(place.address)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: T.caption,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: VerdictBadge(verdict.level)),
                          _FavoriteBubble(
                            saved: saved,
                            onPressed: onSavedToggle,
                            elevated: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        place.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: T.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${place.contentType} · ${_shortAddr(place.address)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: T.caption,
                          color: T.mute,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict.reason,
                      style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: T.body,
                        fontWeight: FontWeight.w600,
                        color: c.fg,
                        height: 1.45,
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
      ),
    );
  }

  static String _shortAddr(String addr) {
    final parts = addr.split(' ');
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : addr;
  }
}

class _FavoriteBubble extends StatelessWidget {
  const _FavoriteBubble({
    required this.saved,
    required this.onPressed,
    this.elevated = true,
  });

  final bool saved;
  final VoidCallback onPressed;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.card.withValues(alpha: elevated ? .94 : 1),
      shape: const CircleBorder(),
      elevation: elevated ? 1 : 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: saved ? T.brandDeep : T.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: T.brandMist,
    child: Center(
      child: PetPassMascot(size: 76, kind: PetPassMascotKind.sitting),
    ),
  );
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetPassMascot(size: 104),
            SizedBox(height: 18),
            Text(
              '조건에 맞는 곳이 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: T.ink,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '필터를 조금 줄이거나 다른 지역을 확인해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 12.5,
                color: T.inkSoft,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
