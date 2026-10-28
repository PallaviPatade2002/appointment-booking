import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const primary = Color(0xFF4F46E5);
const primarySoft = Color(0xFFEEF0FF);
const bg = Color(0xFFF6F7FB);
const ink = Color(0xFF1C2033);
const muted = Color(0xFF6B7189);
const line = Color(0xFFE4E7F0);
const okColor = Color(0xFF16A34A);
const badColor = Color(0xFFDC2626);
const warnColor = Color(0xFFD97706);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: primary, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primarySoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    ),
  );
}

String money(num n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

String duration(int m) => m >= 60 ? '${m ~/ 60}h${m % 60 > 0 ? ' ${m % 60}m' : ''}' : '$m min';

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String niceDate(String iso) => DateFormat('EEE, d MMM y').format(DateTime.parse(iso));

String time12(String t) {
  final p = t.split(':');
  final h = int.parse(p[0]);
  return '${h % 12 == 0 ? 12 : h % 12}:${p[1]} ${h < 12 ? 'AM' : 'PM'}';
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}
