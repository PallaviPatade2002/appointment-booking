import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Override at build time: flutter run --dart-define=API_URL=https://your-server.com
const _envUrl = String.fromEnvironment('API_URL');

String get baseUrl {
  if (_envUrl.isNotEmpty) return _envUrl;
  // Android emulator reaches the host machine at 10.0.2.2
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5001';
  return 'http://localhost:5001';
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class User {
  User({required this.id, required this.name, required this.phone, required this.role});
  final int id;
  final String name;
  final String phone;
  final String role;

  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: j['id'], name: j['name'] ?? '', phone: j['phone'] ?? '', role: j['role']);
}

class Service {
  Service.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        description = j['description'] ?? '',
        durationMin = j['duration_min'],
        price = (j['price'] as num).toDouble();
  final int id;
  final String name;
  final String description;
  final int durationMin;
  final double price;
}

class Booking {
  Booking.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        serviceName = j['service_name'],
        date = j['date'],
        start = j['start'],
        end = j['end'],
        status = j['status'],
        note = j['note'],
        price = (j['price'] as num).toDouble();
  final int id;
  final String serviceName;
  final String date;
  final String start;
  final String end;
  final String status;
  final String? note;
  final double price;
}

class Api {
  Api._();
  static final Api instance = Api._();

  String? _token;
  User? user;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
    final u = p.getString('user');
    if (u != null) user = User.fromJson(jsonDecode(u));
  }

  Future<void> _save(Map<String, dynamic> data) async {
    _token = data['token'];
    user = User.fromJson(data['user']);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', _token!);
    await p.setString('user', jsonEncode(data['user']));
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
  }

  Future<dynamic> _call(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl/api$path'));
    req.headers['Content-Type'] = 'application/json';
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your internet and try again.');
    }
    final data = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException((data is Map ? data['error'] : null) ?? 'Something went wrong');
    }
    return data;
  }

  Future<void> login(String phone, String password) async =>
      _save(await _call('POST', '/auth/login', {'phone': phone, 'password': password}));

  Future<void> register(String name, String phone, String password) async =>
      _save(await _call('POST', '/auth/register', {'name': name, 'phone': phone, 'password': password}));

  Future<List<Service>> services() async =>
      ((await _call('GET', '/services')) as List).map((e) => Service.fromJson(e)).toList();

  Future<List<String>> slots(String date, int serviceId) async =>
      List<String>.from((await _call('GET', '/slots?date=$date&service_id=$serviceId'))['slots']);

  Future<void> book(int serviceId, String date, String time, String note) =>
      _call('POST', '/bookings', {'service_id': serviceId, 'date': date, 'time': time, 'note': note});

  Future<List<Booking>> myBookings() async =>
      ((await _call('GET', '/bookings/mine')) as List).map((e) => Booking.fromJson(e)).toList();

  Future<void> cancel(int id) => _call('PATCH', '/bookings/$id/cancel');
}
