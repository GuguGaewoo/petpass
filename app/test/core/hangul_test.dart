/// 초성 검색 유닛 테스트.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:petpass/core/hangul.dart';

void main() {
  group('초성 추출', () {
    test('음절에서 초성을 뽑는다', () {
      expect(initialOf('남'), 'ㄴ');
      expect(initialOf('산'), 'ㅅ');
      expect(initialOf('골'), 'ㄱ');
      expect(initialOf('꽃'), 'ㄲ');
    });

    test('한글이 아니면 그대로 돌려준다', () {
      expect(initialOf('A'), 'A');
      expect(initialOf('1'), '1');
      expect(initialOf('ㄱ'), 'ㄱ');
    });
  });

  group('일반 검색', () {
    test('부분 문자열로 찾는다', () {
      expect(matchesKorean('남산골한옥마을', '남산'), isTrue);
      expect(matchesKorean('남산골한옥마을', '한옥'), isTrue);
      expect(matchesKorean('남산골한옥마을', '마을'), isTrue);
    });

    test('없는 문자열은 찾지 못한다', () {
      expect(matchesKorean('남산골한옥마을', '경복궁'), isFalse);
    });

    test('빈 질의어는 모두 통과한다', () {
      expect(matchesKorean('남산골한옥마을', ''), isTrue);
    });
  });

  group('초성 검색', () {
    test('초성만으로 찾는다', () {
      expect(matchesKorean('남산골한옥마을', 'ㄴㅅㄱ'), isTrue);
      expect(matchesKorean('남산골한옥마을', 'ㅎㅇㅁㅇ'), isTrue);
    });

    test('맞지 않는 초성은 걸러진다', () {
      expect(matchesKorean('남산골한옥마을', 'ㄱㅂㄱ'), isFalse);
    });

    test('연속하지 않으면 찾지 못한다', () {
      // ㄴ(남) 다음에 ㄱ(골)이 오지만 사이에 산이 있다
      expect(matchesKorean('남산골한옥마을', 'ㄴㄱ'), isFalse);
    });
  });

  group('혼합 검색', () {
    test('완성 글자와 초성을 섞어 찾는다', () {
      // 한글 입력 중 계속 발생하는 상태다
      expect(matchesKorean('남산골한옥마을', '남ㅅㄱ'), isTrue);
      expect(matchesKorean('남산골한옥마을', '남산ㄱ'), isTrue);
      expect(matchesKorean('남산골한옥마을', 'ㄴ산골'), isTrue);
    });

    test('중간부터도 찾는다', () {
      expect(matchesKorean('남산골한옥마을', '골ㅎ'), isTrue);
    });
  });

  group('실제 장소명', () {
    test('금강습지생태공원', () {
      expect(matchesKorean('금강습지생태공원', 'ㄱㄱㅅ'), isTrue);
      expect(matchesKorean('금강습지생태공원', '금강'), isTrue);
      expect(matchesKorean('금강습지생태공원', '생태공원'), isTrue);
      expect(matchesKorean('금강습지생태공원', 'ㅅㅌㄱㅇ'), isTrue);
    });

    test('영문과 숫자가 섞인 이름', () {
      expect(matchesKorean('007 양평점', '양평'), isTrue);
      expect(matchesKorean('007 양평점', 'ㅇㅍ'), isTrue);
      expect(matchesKorean('007 양평점', '007'), isTrue);
    });

    test('대소문자를 가리지 않는다', () {
      expect(matchesKorean('DDP 동대문', 'ddp'), isTrue);
      expect(matchesKorean('DDP 동대문', 'DDP'), isTrue);
    });
  });
}
