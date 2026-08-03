/// 플랫폼별 동작 차이.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

class P {
  /// 웹에서 TourAPI 이미지를 표시할 수 있는가.
  ///
  /// tong.visitkorea.or.kr 이 CORS 헤더를 주지 않아 브라우저가 차단한다.
  /// https 로 요청해도 Access-Control-Allow-Origin 이 없어 마찬가지다.
  /// 앱에는 CORS 제약이 없어 정상 표시된다.
  ///
  /// 프록시 서버를 두면 우회할 수 있으나, "핵심 기능은 외부 서비스에
  /// 의존하지 않는다"는 원칙이 깨진다. 이미지를 내려받아 번들하는 것은
  /// 공사가 URL 참조를 당부했으므로 하지 않는다.
  /// 회색 박스를 줄줄이 보여주느니 영역을 만들지 않는 편이 낫다.
  static bool get canShowTourImage => !kIsWeb;
}
