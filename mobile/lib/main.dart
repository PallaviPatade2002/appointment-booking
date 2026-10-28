import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.restore();
  runApp(const GlowApp());
}

class GlowApp extends StatefulWidget {
  const GlowApp({super.key});

  @override
  State<GlowApp> createState() => _GlowAppState();
}

class _GlowAppState extends State<GlowApp> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final user = Api.instance.user;
    return MaterialApp(
      title: 'Glow Studio',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: user == null ? LoginScreen(onAuth: _refresh) : HomeScreen(onLogout: _refresh),
    );
  }
}
