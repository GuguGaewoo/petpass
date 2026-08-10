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

/// 장소별 제보 집계.
///
/// 본문은 읽지 않는다. 검증되지 않은 텍스트를 그대로 노출하면
/// 잘못된 정보가 퍼지고, 악의적 입력을 걸러낼 수단이 없다.
/// 대신 이용자가 고른 선택지를 집계해 한 문장으로 만든다.
class ReportSummary {
  const ReportSummary({
    required this.total,
    required this.accurate,
    required this.outdated,
    required this.wrong,
  });

  final int total;
  final int accurate;
  final int outdated;
  final int wrong;

  /// 화면에 보여줄 한 줄. 가장 많이 선택된 유형을 기준으로 쓴다.
  String get line {
    if (total == 0) {
      return '';
    }
    final off = outdated + wrong;
    if (off == 0) {
      return total == 1
          ? '방문한 이용자가 판정이 정확했다고 알렸습니다'
          : '방문한 $total명 모두 판정이 정확했다고 알렸습니다';
    }
    if (accurate == 0 && total == off) {
      final what = wrong >= outdated ? '실제와 다르다고' : '최신이 아니라고';
      return total == 1
          ? '방문한 이용자가 정보가 $what 알렸습니다'
          : '방문한 $total명 모두 정보가 $what 알렸습니다';
    }
    final what = wrong >= outdated ? '실제와 다르다고' : '최신이 아니라고';
    return '방문한 $total명 중 $off명이 정보가 $what 알렸습니다';
  }

  /// 주의를 요하는가. 화면에서 강조 여부를 정한다.
  bool get needsCaution => outdated + wrong > accurate;
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
    // ignore: avoid_print
    print(
      '[제보] 키 확인: ${Env.supabasePublishableKey.length}자, 앞 6자=${Env.supabasePublishableKey.isEmpty ? "(비어있음)" : Env.supabasePublishableKey.substring(0, 6)}',
    );
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
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

  /// 장소별 제보 집계. 본문은 읽지 않는다.
  /// 실패하면 null 을 반환하고 화면은 아무것도 표시하지 않는다.
  Future<ReportSummary?> summaryOf(String contentId) async {
    if (!_ready) {
      return null;
    }
    try {
      final rows = await Supabase.instance.client
          .from('report_counts')
          .select('total, accurate, outdated, wrong')
          .eq('content_id', contentId)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      final r = rows.first;
      return ReportSummary(
        total: (r['total'] as num).toInt(),
        accurate: (r['accurate'] as num).toInt(),
        outdated: (r['outdated'] as num).toInt(),
        wrong: (r['wrong'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
