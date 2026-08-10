/// 현장 제보 (F-10).
///
/// 판정이 실제와 맞는지 이용자에게 묻는다. 수집한 내용은 정규화 규칙을
/// 개선하는 우선순위 자료로 쓴다.
///
/// 개인정보를 수집하지 않는다. 제보 본문은 다른 이용자에게 노출하지 않으며,
/// 전송에 실패해도 앱의 다른 기능은 영향을 받지 않는다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../../data/report_repository.dart';
import '../../domain/models/place_constraint.dart';

Future<void> showReportSheet(
  BuildContext context, {
  required AppState state,
  required PlaceConstraint place,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _Sheet(state: state, place: place),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.state, required this.place});

  final AppState state;
  final PlaceConstraint place;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  ReportKind? _kind;
  final _body = TextEditingController();
  bool _sending = false;
  bool? _result;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_kind == null || _sending) {
      return;
    }
    setState(() => _sending = true);
    final ok = await widget.state.submitReport(
      place: widget.place,
      kind: _kind!,
      body: _body.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _sending = false;
      _result = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 키보드가 올라와도 입력란이 가려지지 않게 한다
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: _result != null ? _done() : _form(),
        ),
      ),
    );
  }

  Widget _grip() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: T.line,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grip(),
        const SizedBox(height: 20),
        const Text(
          '판정이 실제와 맞았나요?',
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: T.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.place.title,
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 13,
            color: T.mute,
          ),
        ),
        const SizedBox(height: 18),

        for (final k in ReportKind.values) ...[
          _option(k),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 10),
        TextField(
          controller: _body,
          maxLines: 3,
          maxLength: 500,
          style: const TextStyle(fontFamilyFallback: T.kr, fontSize: 14),
          decoration: InputDecoration(
            hintText: '자세한 내용이 있으면 알려주세요 (선택)',
            hintStyle: const TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 13.5,
              color: T.mute,
            ),
            filled: true,
            fillColor: T.paper,
            counterStyle: const TextStyle(fontSize: 11, color: T.mute),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.r),
              borderSide: const BorderSide(color: T.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.r),
              borderSide: const BorderSide(color: T.line),
            ),
          ),
        ),

        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _kind == null || _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: T.brand,
              foregroundColor: T.onBrand,
              disabledBackgroundColor: T.line,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(T.r),
              ),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '보내기',
                    style: TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '개인정보를 수집하지 않습니다. 보내주신 내용은 데이터 정확도를 높이는 데만 사용합니다.',
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 11.5,
            color: T.mute,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _option(ReportKind k) {
    final on = _kind == k;
    return GestureDetector(
      onTap: () => setState(() => _kind = k),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: on ? T.goBg : T.paper,
          border: Border.all(color: on ? T.go : T.line, width: on ? 1.5 : 1),
          borderRadius: BorderRadius.circular(T.r),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 19,
              color: on ? T.go : T.mute,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.label,
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: on ? T.go : T.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  k.hint,
                  style: const TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 12,
                    color: T.mute,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _done() {
    final ok = _result == true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _grip(),
        const SizedBox(height: 34),
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          size: 46,
          color: ok ? T.go : T.mute,
        ),
        const SizedBox(height: 16),
        Text(
          ok ? '보내주셔서 감사합니다' : '지금은 보낼 수 없습니다',
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: T.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ok ? '데이터를 개선하는 데 사용하겠습니다' : '잠시 후 다시 시도해주세요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 13.5,
            color: T.inkSoft,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: T.brand,
              foregroundColor: T.onBrand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(T.r),
              ),
            ),
            child: const Text(
              '닫기',
              style: TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
