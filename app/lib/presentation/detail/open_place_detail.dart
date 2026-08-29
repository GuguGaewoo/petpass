/// 장소 상세화면으로 들어가는 공통 경로.
///
/// 검색·저장·주변 세 화면이 모두 이 함수를 쓴다. 각자 Navigator.push 를
/// 직접 호출하면 실시간 조회를 빠뜨린 곳이 생기기 쉬워 한 곳으로 모았다.
///
/// 상세화면 자체는 넘겨받은 장소를 그리기만 한다. 최신 데이터로 바꾸는
/// 일은 들어가기 직전인 여기서 끝낸다. 덕분에 PlaceDetailScreen 과
/// 판정 엔진은 수정할 필요가 없다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/models/place_constraint.dart';
import 'place_detail_screen.dart';

/// 최신 조건을 확인한 뒤 상세화면을 연다.
///
/// [navigator] 를 BuildContext 대신 받는 이유는, 바텀시트처럼 자신을
/// 먼저 닫아야 하는 호출부가 있기 때문이다. 그런 곳은 pop 하기 전에
/// Navigator 를 미리 잡아 두고 넘긴다.
///
/// 조회에 실패해도 화면은 정상적으로 열린다. 그때는 이미 가지고 있던
/// 데이터를 그대로 쓴다.
Future<void> openPlaceDetail(
  NavigatorState navigator, {
  required AppState state,
  required PlaceConstraint place,
}) async {
  final latest = await state.refreshPlace(place);

  // await 사이에 화면이 사라졌을 수 있다.
  if (!navigator.mounted) return;

  await navigator.push(
    MaterialPageRoute(
      builder: (_) => PlaceDetailScreen(state: state, place: latest),
    ),
  );
}
