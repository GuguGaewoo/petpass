/// 저장한 장소.
///
/// 저장/해제 및 상세 이동 기능은 그대로 유지하고 PetPass 시안의
/// 아이보리·라벤더·둥근 카드 스타일만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/platform.dart';
import '../../core/tokens.dart';
import '../detail/place_detail_screen.dart';
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 21,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
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
                                  '${saved.length}곳',
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
                    ),
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
                              itemBuilder: (context, i) {
                                final p = saved[i];
                                final v = state.judge(p);
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: T.card,
                                    borderRadius: BorderRadius.circular(
                                      T.rCard,
                                    ),
                                    boxShadow: T.softShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      T.rCard,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PlaceDetailScreen(
                                            state: state,
                                            place: p,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (P.canShowTourImage)
                                            SizedBox(
                                              width: 112,
                                              child: p.image.isEmpty
                                                  ? const _SavedNoImage()
                                                  : Image.network(
                                                      p.image,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, _, _) =>
                                                          const _SavedNoImage(),
                                                      loadingBuilder:
                                                          (ctx, child, progress) =>
                                                              progress == null
                                                              ? child
                                                              : const _SavedNoImage(),
                                                    ),
                                            ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(
                                                15,
                                                14,
                                                8,
                                                14,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  VerdictBadge(v.level),
                                                  const SizedBox(height: 9),
                                                  Text(
                                                    p.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamilyFallback: T.kr,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: T.ink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${p.contentType} · ${_shortAddr(p.address)}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamilyFallback: T.kr,
                                                      fontSize: 11.5,
                                                      color: T.mute,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 7),
                                                  Text(
                                                    v.reason,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamilyFallback: T.kr,
                                                      fontSize: 12.5,
                                                      height: 1.4,
                                                      color: verdictColors(
                                                        v.level,
                                                      ).fg,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                              right: 7,
                                            ),
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: IconButton(
                                                onPressed: () => state
                                                    .toggleSaved(p.contentId),
                                                icon: const Icon(
                                                  Icons.favorite_rounded,
                                                  size: 21,
                                                  color: T.brand,
                                                ),
                                                tooltip: '저장 해제',
                                              ),
                                            ),
                                          ),
                                        ],
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
      },
    );
  }

  static String _shortAddr(String addr) {
    final parts = addr.split(' ');
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : addr;
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
            PetPassMascot(size: 106),
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
              '장소 상세에서 하트 아이콘을 누르면\n여기에 모아볼 수 있어요.',
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
        child: Icon(Icons.pets_rounded, size: 27, color: T.brand),
      ),
    );
  }
}
