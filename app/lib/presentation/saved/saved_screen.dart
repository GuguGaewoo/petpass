/// 저장한 장소.
///
/// 저장 목록은 기기 안에만 둔다. 프로필과 같은 원칙이다.
/// 판정은 저장 시점이 아니라 화면을 그리는 시점에 다시 계산하므로,
/// 프로필을 바꾸면 저장해 둔 곳의 판정도 함께 바뀐다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../detail/place_detail_screen.dart';
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, size: 20),
                            color: T.inkSoft,
                          ),
                          const Expanded(
                            child: Text(
                              '저장한 곳',
                              style: TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: T.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${saved.length}곳',
                            style: T.mono.copyWith(
                              fontSize: 12,
                              color: T.inkSoft,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    Expanded(
                      child: saved.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  '저장한 곳이 없습니다.\n'
                                  '장소 상세에서 별 아이콘을 눌러 저장하세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamilyFallback: T.kr,
                                    fontSize: 14,
                                    color: T.inkSoft,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                24,
                              ),
                              itemCount: saved.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final p = saved[i];
                                final v = state.judge(p);
                                return Material(
                                  color: T.card,
                                  borderRadius: BorderRadius.circular(T.rCard),
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
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: T.line),
                                        borderRadius: BorderRadius.circular(
                                          T.rCard,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          VerdictBadge(v.level),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamilyFallback: T.kr,
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: T.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  v.reason,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamilyFallback: T.kr,
                                                    fontSize: 12.5,
                                                    color: verdictColors(
                                                      v.level,
                                                    ).fg,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                state.toggleSaved(p.contentId),
                                            icon: const Icon(
                                              Icons.star,
                                              size: 20,
                                              color: T.hold,
                                            ),
                                            tooltip: '저장 해제',
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
}
