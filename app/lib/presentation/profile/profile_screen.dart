/// 반려동물 프로필 입력.
///
/// 체중 눈금에 10kg 를 표시한다. 전국 632건 실사에서 체중 상한이 10kg 에
/// 몰려 있어, 사용자가 그 경계를 인지하는 것이 판정 이해에 직접 도움이 된다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../../domain/models/pet_profile.dart';
import '../search/search_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  double _weight = 5;
  DogSize? _sizeOverride;
  bool _fierce = false;
  bool _guideDog = false;

  @override
  void initState() {
    super.initState();
    final p = widget.state.pet;
    if (p != null) {
      _name.text = p.name;
      _weight = p.weightKg;
      _sizeOverride = p.size;
      _fierce = p.isFierce;
      _guideDog = p.isGuideDog;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DogSize get _size => _sizeOverride ?? DogSize.fromWeight(_weight);

  void _submit() {
    widget.state.setPet(PetProfile(
      name: _name.text.trim().isEmpty ? '우리 아이' : _name.text.trim(),
      weightKg: _weight,
      size: _size,
      isFierce: _fierce,
      isGuideDog: _guideDog,
    ));
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchScreen(state: widget.state),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              children: [
                const Text('펫패스',
                    style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: T.ink)),
                const SizedBox(height: 6),
                const Text('반려동물과 갈 수 있는 곳인지 미리 확인하세요',
                    style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 14.5,
                        color: T.inkSoft,
                        height: 1.5)),
                const SizedBox(height: 36),

                _label('이름'),
                TextField(
                  controller: _name,
                  style: const TextStyle(fontFamilyFallback: T.kr, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '우리 아이',
                    filled: true,
                    fillColor: T.card,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                const SizedBox(height: 28),

                _label('체중'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_weight.toStringAsFixed(1),
                        style: T.mono.copyWith(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                            height: 1)),
                    const SizedBox(width: 4),
                    const Text('kg',
                        style: TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 16,
                            color: T.inkSoft)),
                    const Spacer(),
                    Text(_size.label,
                        style: const TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 14,
                            color: T.inkSoft)),
                  ],
                ),
                Slider(
                  value: _weight,
                  min: 0.5,
                  max: 45,
                  divisions: 89,
                  activeColor: T.go,
                  inactiveColor: T.line,
                  onChanged: (v) => setState(() {
                    _weight = v;
                    _sizeOverride = null;
                  }),
                ),
                _weightRuler(),
                const SizedBox(height: 28),

                _label('해당하면 알려주세요'),
                _check(
                  value: _guideDog,
                  onChanged: (v) => setState(() => _guideDog = v),
                  title: '장애인 보조견입니다',
                  note: '보조견은 법으로 출입이 보장되어, 체중·견종 제한을 적용하지 않습니다',
                ),
                _check(
                  value: _fierce,
                  onChanged: (v) => setState(() => _fierce = v),
                  title: '맹견으로 분류됩니다',
                  note: '도사견, 아메리칸 핏불테리어 등',
                ),
                const SizedBox(height: 36),

                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: T.ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(T.r)),
                    ),
                    child: const Text('장소 찾아보기',
                        style: TextStyle(
                            fontFamilyFallback: T.kr,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '입력한 정보는 이 기기에만 저장되며 어디에도 전송하지 않습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamilyFallback: T.kr, fontSize: 12, color: T.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 10kg 눈금. 데이터상 판정이 가장 많이 갈리는 지점이라 표시한다.
  Widget _weightRuler() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: LayoutBuilder(builder: (context, c) {
        const min = 0.5, max = 45.0;
        final x = (10 - min) / (max - min) * c.maxWidth;
        return SizedBox(
          height: 26,
          child: Stack(children: [
            Positioned(
              left: x - 40,
              width: 80,
              child: Column(children: [
                Container(width: 1, height: 6, color: T.inkSoft),
                const SizedBox(height: 3),
                const Text('10kg',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamilyFallback: T.monoStack,
                        fontSize: 10.5,
                        color: T.inkSoft)),
                const Text('제한이 몰리는 기준',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamilyFallback: T.kr, fontSize: 9.5, color: T.mute)),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s,
            style: const TextStyle(
                fontFamilyFallback: T.kr,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: T.inkSoft,
                letterSpacing: 0.3)),
      );

  Widget _check({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String note,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(T.r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: T.ink,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(title,
                    style: const TextStyle(
                        fontFamilyFallback: T.kr, fontSize: 14.5, color: T.ink)),
              ),
              const SizedBox(height: 2),
              Text(note,
                  style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 12,
                      color: T.inkSoft,
                      height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}
