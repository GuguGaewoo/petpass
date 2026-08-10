/// 현장 제보 저장소 (F-10).
///
/// 이 서비스에서 유일하게 외부 저장소를 쓰는 기능이다.
/// 판정·검색·지도·주변 추천은 모두 앱에 포함된 데이터로 동작하므로,
/// 저장소가 동작하지 않아도 서비스의 핵심은 영향을 받지 않는다.
///
/// 개인정보를 수집하지 않는다. 기기 식별자는 앱이 생성한 난수이며
/// 사용자나 기기를 특정할 수 없다.
library;

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

/// 제보 유형. 데이터베이스의 check 제약과 값이 일치해야 한다.
enum ReportKind {
  accurate('accurate', '정확해요', '판정이 실제와 맞았습니다'),
  outdated('outdated', '최신이 아니에요', '조건이 바뀐 것 같습니다'),
  wrong('wrong', '틀렸어요', '판정이 실제와 다릅니다');

  const ReportKind(this.value, this.label, this.hint);
  final String value;
  final String label;
  final String hint;
}

class ReportRepository {
  static const _deviceKey = 'device_hash';

  bool _ready = false;

  /// 앱 시작 시 한 번 호출한다.
  /// 키가 없거나 초기화에 실패해도 예외를 밖으로 내보내지 않는다.
  Future<void> init() async {
    if (!Env.hasReportBackend) {
      return;
    }
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  bool get isAvailable => _ready;

  /// 익명 기기 식별자. 최초 호출 시 난수를 만들어 기기에 저장한다.
  /// 같은 사람이 한 장소에 반복 제보하는 것을 걸러내는 용도로만 쓴다.
  Future<String> _deviceHash() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceKey);
    if (saved != null) {
      return saved;
    }
    final r = Random.secure();
    final hash = List.generate(
      16,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    await prefs.setString(_deviceKey, hash);
    return hash;
  }

  /// 제보를 보낸다. 실패하면 false 를 반환하고 예외를 던지지 않는다.
  Future<bool> submit({
    required String contentId,
    required String placeTitle,
    required ReportKind kind,
    String body = '',
  }) async {
    if (!_ready) {
      return false;
    }
    try {
      await Supabase.instance.client.from('reports').insert({
        'content_id': contentId,
        'place_title': placeTitle,
        'verdict_feedback': kind.value,
        'body': body.trim(),
        'device_hash': await _deviceHash(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 장소별 제보 건수. 본문은 읽지 않는다.
  /// 실패하면 null 을 반환하고 화면은 건수를 표시하지 않는다.
  Future<int?> countOf(String contentId) async {
    if (!_ready) {
      return null;
    }
    try {
      final rows = await Supabase.instance.client
          .from('report_counts')
          .select('total')
          .eq('content_id', contentId)
          .limit(1);
      if (rows.isEmpty) {
        return 0;
      }
      return (rows.first['total'] as num).toInt();
    } catch (_) {
      return null;
    }
  }
}
