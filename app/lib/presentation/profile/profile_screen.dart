/// 반려동물 프로필 입력.
///
/// 기존 프로필 저장/판정 흐름은 그대로 두고 PetPass 시안의
/// 아이보리·라벤더·둥근 카드 스타일만 적용한다.
library;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/tokens.dart';
import '../../domain/models/pet_profile.dart';
import '../search/search_screen.dart';
import '../widgets/petpass_decor.dart';

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
    widget.state.setPet(
      PetProfile(
        name: _name.text.trim().isEmpty ? '우리 아이' : _name.text.trim(),
        weightKg: _weight,
        size: _size,
        isFierce: _fierce,
        isGuideDog: _guideDog,
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchScreen(state: widget.state)),
    );
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
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
              children: [
                const _TitleBar(),
                const SizedBox(height: 18),
                const _PetAvatar(),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(T.rCard),
                    border: Border.all(color: T.line),
                    boxShadow: T.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('이름'),
                      TextField(
                        controller: _name,
                        style: const TextStyle(
                          fontFamilyFallback: T.kr,
                          fontSize: 15.5,
                          color: T.ink,
                        ),
                        decoration: _inputDecoration('이름을 입력해주세요'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _label('체중'),
                          const Spacer(),
                          Text(
                            '${_weight.toStringAsFixed(1)} kg',
                            style: T.mono.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: T.ink,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: T.brand,
                          inactiveTrackColor: T.line,
                          thumbColor: T.brand,
                          overlayColor: T.brandSoft,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _weight,
                          min: 0.5,
                          max: 45,
                          divisions: 89,
                          onChanged: (v) => setState(() {
                            _weight = v;
                            _sizeOverride = null;
                          }),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '0.5kg',
                            style: T.mono.copyWith(fontSize: 10.5, color: T.mute),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: T.brandMist,
                              borderRadius: BorderRadius.circular(T.rPill),
                            ),
                            child: Text(
                              _size.label,
                              style: const TextStyle(
                                fontFamilyFallback: T.kr,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: T.brandDeep,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '45kg',
                            style: T.mono.copyWith(fontSize: 10.5, color: T.mute),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _toggle(
                        title: '맹견 여부',
                        note: '맹견에 해당하면 켜주세요',
                        value: _fierce,
                        onChanged: (v) => setState(() => _fierce = v),
                      ),
                      const Divider(height: 1, color: T.line),
                      _toggle(
                        title: '보조견(안내견) 여부',
                        note: '보조견은 별도 기준으로 판정합니다',
                        value: _guideDog,
                        onChanged: (v) => setState(() => _guideDog = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.pets_rounded, size: 20),
                    label: const Text(
                      '저장하고 장소 찾기',
                      style: TextStyle(
                        fontFamilyFallback: T.kr,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: T.brand,
                      foregroundColor: T.onBrand,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rPill),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  '입력한 정보는 이 기기에만 저장되며 어디에도 전송하지 않습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamilyFallback: T.kr,
                    fontSize: 11.5,
                    color: T.mute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamilyFallback: T.kr,
      color: T.mute,
      fontSize: 14,
    ),
    filled: true,
    fillColor: T.paper,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
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
  );

  Widget _label(String s) => Text(
    s,
    style: const TextStyle(
      fontFamilyFallback: T.kr,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: T.ink,
    ),
  );

  Widget _toggle({
    required String title,
    required String note,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(T.r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 11.5,
                      color: T.mute,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: T.brand,
              activeTrackColor: T.brandSoft,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          '반려견 프로필',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: T.ink,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '우리 아이에게 맞는 동반 조건을 확인해요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamilyFallback: T.kr,
            fontSize: 11.5,
            color: T.mute,
          ),
        ),
      ],
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: PetPassMascot(size: 118),
    );
  }
}
