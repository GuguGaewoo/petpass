import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'core/tokens.dart';
import 'presentation/profile/profile_screen.dart';
import 'presentation/widgets/petpass_decor.dart';

void main() => runApp(const PetPassApp());

class PetPassApp extends StatefulWidget {
  const PetPassApp({super.key});

  @override
  State<PetPassApp> createState() => _PetPassAppState();
}

class _PetPassAppState extends State<PetPassApp> {
  final _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '펫패스',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AllDeviceScroll(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: T.brand),
        scaffoldBackgroundColor: T.paper,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (_state.loading) {
            return const Scaffold(
              backgroundColor: T.paper,
              body: Center(child: CircularProgressIndicator(color: T.brand)),
            );
          }
          if (_state.error != null) {
            return Scaffold(
              backgroundColor: T.paper,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamilyFallback: T.kr,
                      fontSize: 14,
                      color: T.stop,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            );
          }
          return PetPassBackdrop(
            dense: true,
            child: ProfileScreen(state: _state),
          );
        },
      ),
    );
  }
}

class _AllDeviceScroll extends MaterialScrollBehavior {
  const _AllDeviceScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
