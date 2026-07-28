/// 장소 목록. 프로필과 대조한 판정을 함께 보여준다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/area_codes.dart';
import '../../core/tokens.dart';
import '../../domain/models/place_constraint.dart';
import '../../domain/models/verdict.dart';
import '../detail/place_detail_screen.dart';
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
  bool _hidePossibleOnly = false;

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
          !p.address.contains(_query))
        return false;
      return true;
    }).toList();

    final judged = [for (final p in list) (place: p, verdict: s.judge(p))];
    if (_hidePossibleOnly) {
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
                              : '${pet.name} · ${pet.weightKg.toStringAsFixed(1)}kg · ${pet.size.label}',
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                          ),
                        ),
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
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _filter(
                        '가능한 곳만',
                        _hidePossibleOnly,
                        () => setState(
                          () => _hidePossibleOnly = !_hidePossibleOnly,
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (final t in _types) ...[
                        _filter(
                          t,
                          _type == t,
                          () => setState(() => _type = _type == t ? null : t),
                        ),
                        const SizedBox(width: 6),
                      ],
                      for (final e in areaNames.entries) ...[
                        _filter(
                          e.value,
                          _area == e.key,
                          () => setState(
                            () => _area = _area == e.key ? null : e.key,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
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

  Widget _filter(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 8),
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
    // Material 을 가장 바깥에 두고 카드 배경색을 여기서 칠한다.
    // 그래야 InkWell 물결이 배경 '위에' 그려진다.
    return Material(
      color: T.card, // Container 의 decoration.color 를 여기로 옮김
      borderRadius: BorderRadius.circular(T.rCard),
      clipBehavior: Clip.antiAlias, // 물결이 둥근 모서리를 넘지 않게
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // color 는 위 Material 로 이동했다
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.rCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VerdictBadge(verdict.level),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${place.contentType} · ${place.address}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 12,
                            color: T.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                verdict.reason,
                style: TextStyle(
                  fontFamilyFallback: T.kr,
                  fontSize: 13.5,
                  color: verdictColors(verdict.level).fg,
                  height: 1.4,
                ),
              ),
              if (verdict.chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [for (final c in verdict.chips) InfoChip(c)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
