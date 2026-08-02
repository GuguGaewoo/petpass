/// 플랫폼별 동작 차이.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

class P {
  /// 웹에서 TourAPI 이미지를 표시할 수 있는가.
  ///
  /// tong.visitkorea.or.kr 이 CORS 헤더를 주지 않아 브라우저가 차단한다.
  /// 앱(Android)에는 CORS 제약이 없어 정상 표시된다.
  /// 빈 회색 박스를 보여주느니 자리를 만들지 않는 편이 낫다.
  static bool get canShowTourImage => !kIsWeb;
}
