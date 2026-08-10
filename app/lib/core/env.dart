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
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 제보 기능을 쓸 수 있는가.
  /// 키가 없으면 제보 버튼을 노출하지 않는다. 핵심 기능은 영향받지 않는다.
  static bool get hasReportBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
