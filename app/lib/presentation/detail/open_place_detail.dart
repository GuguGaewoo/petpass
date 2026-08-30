/// 장소 상세화면으로 들어가는 공통 경로.
///
/// 검색·저장·주변 세 화면이 모두 이 함수를 쓴다. 각자 Navigator.push 를
/// 직접 호출하면 실시간 조회를 빠뜨린 곳이 생기기 쉬워 한 곳으로 모았다.
///
/// 화면을 먼저 열고 최신 조건 확인은 배경에서 진행한다. 서버가 잠들어
/// 있으면 응답에 1분 가까이 걸릴 수 있는데, 그동안 사용자를 기다리게
/// 하면 앱이 멈춘 것처럼 보인다. 이미 가지고 있는 데이터로 화면을 바로
/// 그리고, 확인이 끝나면 조용히 갱신한다.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/models/place_constraint.dart';
import 'place_detail_screen.dart';

/// 상세화면을 즉시 열고, 최신 조건은 배경에서 확인한다.
///
/// [navigator] 를 BuildContext 대신 받는 이유는, 바텀시트처럼 자신을
/// 먼저 닫아야 하는 호출부가 있기 때문이다. 그런 곳은 pop 하기 전에
/// Navigator 를 미리 잡아 두고 넘긴다.
void openPlaceDetail(
  NavigatorState navigator, {
  required AppState state,
  required PlaceConstraint place,
}) {
  // 화면을 먼저 띄운다. 대기 시간 없음.
  navigator.push(
    MaterialPageRoute(
      builder: (_) => PlaceDetailScreen(
        state: state,
        contentId: place.contentId,
        fallback: place,
      ),
    ),
  );

  // 배경에서 최신 조건을 확인한다.
  // 실패는 refreshPlace 안에서 처리하므로 기다리거나 잡을 필요가 없다.
  unawaited(state.refreshPlace(place));
}
