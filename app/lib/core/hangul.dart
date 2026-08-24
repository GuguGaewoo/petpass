/// 한글 초성 검색.
///
/// "ㄴㅅㄱ" 로 "남산골한옥마을" 을 찾는다. 완성 글자와 초성을 섞어
/// "남ㅅㄱ" 로도 찾을 수 있다. 한글 입력 중에는 "남산ㄱ" 같은 중간
/// 상태가 계속 생기므로, 혼합을 지원해야 타이핑하는 동안 목록이
/// 끊기지 않고 좁혀진다.
///
/// 순수 Dart. Flutter 를 import 하지 않으므로 유닛 테스트로 검증한다.
library;

/// 한글 음절의 유니코드 범위
const int _syllableStart = 0xAC00; // 가
const int _syllableEnd = 0xD7A3; // 힣

/// 음절 하나가 가지는 중성×종성 조합 수 (21 × 28)
const int _jungJongCount = 588;

/// 초성 19자. 인덱스가 음절 분해 결과와 대응한다.
const List<String> _initials = [
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

/// 이 문자가 단독으로 쓰인 초성인가.
///
/// 'ㄱ' 처럼 자음만 입력된 상태를 뜻한다. 'ㅏ' 같은 모음이나
/// 'ㄳ' 같은 겹받침은 초성으로 쓰이지 않으므로 제외한다.
bool isInitialChar(String ch) => _initials.contains(ch);

/// 음절 하나에서 초성을 뽑는다. 한글이 아니면 그대로 돌려준다.
String initialOf(String ch) {
  if (ch.isEmpty) {
    return ch;
  }
  final code = ch.codeUnitAt(0);
  if (code < _syllableStart || code > _syllableEnd) {
    return ch;
  }
  return _initials[(code - _syllableStart) ~/ _jungJongCount];
}

/// [text] 가 [query] 로 검색되는가.
///
/// 질의어를 한 글자씩 보면서
///   - 초성 문자면 대상 글자의 초성과 비교하고
///   - 그 외에는 글자 자체를 비교한다
/// 대상의 어느 위치에서 시작하든 연속으로 일치하면 참이다.
bool matchesKorean(String text, String query) {
  if (query.isEmpty) {
    return true;
  }
  if (text.isEmpty) {
    return false;
  }

  final t = text.toLowerCase();
  final q = query.toLowerCase().replaceAll(' ', '');
  if (q.isEmpty) {
    return true;
  }

  // 시작 위치를 옮겨가며 연속 일치를 찾는다.
  // 632건 × 짧은 질의어라 단순 순회로 충분하다.
  for (var start = 0; start + q.length <= t.length; start++) {
    var ok = true;
    for (var i = 0; i < q.length; i++) {
      final qc = q[i];
      final tc = t[start + i];
      final hit = isInitialChar(qc) ? initialOf(tc) == qc : tc == qc;
      if (!hit) {
        ok = false;
        break;
      }
    }
    if (ok) {
      return true;
    }
  }
  return false;
}
