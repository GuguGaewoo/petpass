/// 저장한 장소.
///
/// 저장/해제 및 상세 이동 기능은 그대로 유지하고 PetPass 시안의
/// 아이보리·라벤더·둥근 카드 스타일만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/platform.dart';
import '../../core/tokens.dart';
import '../../domain/models/place_constraint.dart';
import '../detail/open_place_detail.dart';
import '../widgets/petpass_decor.dart';
import '../widgets/verdict_badge.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final saved = state.savedPlaces;
        return Scaffold(
          backgroundColor: T.paper,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    _Header(count: saved.length),
                    Expanded(
                      child: saved.isEmpty
                          ? const _EmptySaved()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                22,
                                20,
                                28,
                              ),
                              itemCount: saved.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: T.gapCard),
                              itemBuilder: (context, i) =>
                                  _SavedCard(state: state, place: saved[i]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            color: T.inkSoft,
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '저장한 곳',
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: T.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '다시 보고 싶은 장소를 모아두었어요.',
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 11.5,
                    color: T.mute,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: T.brandSoft,
              borderRadius: BorderRadius.circular(T.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 15,
                  color: T.brandDeep,
                ),
                const SizedBox(width: 5),
                Text(
                  '$count곳',
                  style: T.mono.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: T.brandDeep,
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

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.state, required this.place});

  final AppState state;
  final PlaceConstraint place;

  @override
  Widget build(BuildContext context) {
    final verdict = state.judge(place);
    final colors = verdictColors(verdict.level);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: T.brandSoft),
        boxShadow: T.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(T.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPlaceDetail(
            Navigator.of(context),
            state: state,
            place: place,
          ),
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
                          errorBuilder: (_, _, _) => const _SavedNoImage(),
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : const _SavedNoImage(),
                        )
                      else
                        const _SavedNoImage(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB8332D3D)],
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
                          onPressed: () => state.toggleSaved(place.contentId),
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
                                color: Colors.white.withValues(alpha: .84),
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
                  child: Row(
                    children: [
                      VerdictBadge(verdict.level),
                      const Spacer(),
                      _FavoriteBubble(
                        onPressed: () => state.toggleSaved(place.contentId),
                        elevated: false,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!P.canShowTourImage) ...[
                      Text(
                        place.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: T.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${place.contentType} · ${_shortAddr(place.address)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 11.5,
                          color: T.mute,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      verdict.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: colors.fg,
                      ),
                    ),
                    if (verdict.chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final chip in verdict.chips) InfoChip(chip),
                        ],
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
  const _FavoriteBubble({required this.onPressed, this.elevated = true});

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
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.favorite_rounded, size: 20, color: T.brandDeep),
        ),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetPassMascot(size: 112, kind: PetPassMascotKind.sleeping),
            SizedBox(height: 18),
            Text(
              '아직 저장한 장소가 없어요',
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: T.ink,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '장소 카드나 상세 화면의 하트를 누르면\n여기에 모아볼 수 있어요.',
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

class _SavedNoImage extends StatelessWidget {
  const _SavedNoImage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: T.brandMist,
      child: Center(
        child: PetPassMascot(size: 70, kind: PetPassMascotKind.sitting),
      ),
    );
  }
}
