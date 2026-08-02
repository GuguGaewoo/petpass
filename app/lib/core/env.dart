/// 빌드 시 주입되는 설정값.
///
/// 키를 소스에 넣지 않는다. 실행할 때 --dart-define 으로 넘긴다.
///   flutter run -d chrome --web-port=8080 \
///     --dart-define=NAVER_MAP_CLIENT_ID=발급받은값
///
/// 지도 클라이언트 ID 는 브라우저에 노출되는 값이라 완전한 비밀은 아니다.
/// 다만 네이버 콘솔에서 도메인·패키지명을 제한해 두었으므로
/// 등록되지 않은 곳에서는 사용할 수 없다.
library;

class Env {
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

  static bool get hasMapKey => naverMapClientId.isNotEmpty;
}
