/// 현장 제보 (F-10).
///
/// 기존 Supabase 전송/성공·실패 처리 로직은 유지하고 PetPass 시안의
/// 아이보리·라벤더·둥근 선택 카드·발바닥 CTA만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../../data/report_repository.dart';
import '../../domain/models/place_constraint.dart';
import 'petpass_decor.dart';

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
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
    if (_kind == null || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.state.submitReport(
      place: widget.place,
      kind: _kind!,
      body: _body.text,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: T.lineStrong,
        borderRadius: BorderRadius.circular(T.rPill),
      ),
    ),
  );

  Widget _form() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _grip(),
          const SizedBox(height: 19),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: T.brandSoft,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: T.card),
                ),
                child: const Center(child: PetPassPawIcon(size: 22)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '판정이 실제와 맞았나요?',
                      style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: T.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 12.5,
                        color: T.mute,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final k in ReportKind.values) ...[
            _option(k),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 10),
          const Text(
            '추가로 알려주실 내용',
            style: TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: T.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(
              fontFamilyFallback: T.kr,
              fontSize: 14,
              color: T.ink,
            ),
            decoration: InputDecoration(
              hintText: '자세한 내용이 있으면 알려주세요 (선택)',
              hintStyle: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 13,
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(T.r),
                borderSide: const BorderSide(color: T.brand, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          PetPassPrimaryButton(
            label: _sending ? '전송 중' : '제보 보내기',
            height: 54,
            onPressed: _kind == null || _sending ? null : _send,
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.brandMist,
              borderRadius: BorderRadius.circular(T.r),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: T.brand),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '개인정보를 수집하지 않습니다. 보내주신 내용은 데이터 정확도를 높이는 데만 사용합니다.',
                    style: TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 11.5,
                      color: T.inkSoft,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(ReportKind k) {
    final on = _kind == k;
    return GestureDetector(
      onTap: () => setState(() => _kind = k),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: on ? T.brandSoft : T.paper,
          border: Border.all(color: on ? T.brand : T.line, width: on ? 1.5 : 1),
          borderRadius: BorderRadius.circular(T.rCard),
          boxShadow: on ? T.softShadow : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: on ? T.card : T.brandMist,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _kindIcon(k),
                size: 19,
                color: on ? T.brandDeep : T.inkSoft,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    style: TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: on ? T.brandDeep : T.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    k.hint,
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 11.5,
                      color: T.mute,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              on
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: on ? T.brand : T.lineStrong,
            ),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(ReportKind k) {
    final label = k.label;
    if (label.contains('맞') || label.contains('정확')) {
      return Icons.thumb_up_alt_outlined;
    }
    if (label.contains('다르') || label.contains('틀')) {
      return Icons.sync_problem_rounded;
    }
    if (label.contains('변경') || label.contains('바뀜')) {
      return Icons.update_rounded;
    }
    if (label.contains('모르') || label.contains('확인')) {
      return Icons.help_outline_rounded;
    }
    return Icons.flag_outlined;
  }

  Widget _done() {
    final ok = _result == true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _grip(),
        const SizedBox(height: 30),
        if (ok)
          const PetPassMascot(size: 96, kind: PetPassMascotKind.sitting)
        else
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: T.stopBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 39,
              color: T.stop,
            ),
          ),
        const SizedBox(height: 18),
        Text(
          ok ? '보내주셔서 감사합니다' : '지금은 보낼 수 없습니다',
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: T.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          ok ? '데이터를 개선하는 데 사용하겠습니다' : '잠시 후 다시 시도해주세요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 13,
            color: T.inkSoft,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        PetPassPrimaryButton(
          label: '닫기',
          height: 52,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
