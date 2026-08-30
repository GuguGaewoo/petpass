/// 빌드 시 주입되는 설정값.
///
/// 키를 소스에 넣지 않는다. 실행할 때 --dart-define 으로 넘긴다.
/// run_web.sh / build_apk.sh 가 루트 .env 를 읽어 자동으로 처리한다.
library;

class Env {
  /// 지도 클라이언트 ID.
  /// 브라우저에 노출되는 값이지만 네이버 콘솔에서 도메인·패키지명을
  /// 제한해 두었으므로 등록되지 않은 곳에서는 사용할 수 없다.
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

  static bool get hasMapKey => naverMapClientId.isNotEmpty;

  /// 현장 제보 저장소.
  ///
  /// anon 키는 클라이언트에 노출되는 값이다. 다만 RLS 로 삽입만
  /// 허용하고 조회 정책을 두지 않았으므로, 키를 가져도 남의 제보를
  /// 읽거나 지울 수 없다.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// 제보 기능을 쓸 수 있는가.
  /// 키가 없으면 제보 버튼을 노출하지 않는다. 핵심 기능은 영향받지 않는다.
  static bool get hasReportBackend =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// 실시간 상세조회 백엔드 주소.
  ///
  /// 장소 상세에 들어갈 때 이 서버가 관광 Open API 를 다시 호출해
  /// 최신 동반 조건을 확인한다. 인증키는 서버에만 있고 앱에는 없다.
  ///
  /// 비어 있으면 실시간 조회를 건너뛰고 이미 읽어 둔 데이터를 그대로
  /// 쓴다. 즉 이 값이 없어도 화면과 기능은 완전히 동일하게 동작한다.
  static const petpassApiBaseUrl = String.fromEnvironment(
    'PETPASS_API_BASE_URL',
  );

  static bool get hasLiveApi => petpassApiBaseUrl.isNotEmpty;
}
