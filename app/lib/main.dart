import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'rts/screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  runApp(const MiningApp());
}

class MiningApp extends StatelessWidget {
  static const buildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');
  const MiningApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '광맥 · 1편',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFFEBC56A),
      scaffoldBackgroundColor: const Color(0xFFEDE5D2),
    ),
    builder: (context, child) => Stack(
      children: [
        if (child != null) child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          left: 6,
          child: IgnorePointer(
            child: Material(
              color: const Color(0xDD222222),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text('빌드 #$buildNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ),
        ),
      ],
    ),
    home: const _StartupGreeting(child: RtsScreen()),
  );
}

class _StartupGreeting extends StatefulWidget {
  const _StartupGreeting({required this.child});

  final Widget child;

  @override
  State<_StartupGreeting> createState() => _StartupGreetingState();
}

class _StartupGreetingState extends State<_StartupGreeting> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('하이'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
