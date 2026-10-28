import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuth});
  final VoidCallback onAuth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = Api.instance;
      if (_register) {
        await api.register(_name.text.trim(), _phone.text.trim(), _password.text);
      } else {
        await api.login(_phone.text.trim(), _password.text);
      }
      if (api.user!.role != 'customer') {
        await api.logout();
        throw ApiException('Admin accounts use the website. Please login with a customer account.');
      }
      widget.onAuth();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(28, MediaQuery.of(context).padding.top + 48, 28, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4F46E5), Color(0xFF3730A3), Color(0xFF1E1B4B)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.content_cut, color: Colors.white),
                  ),
                  SizedBox(height: 24),
                  Text('Glow Studio',
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Book your appointment in a few taps.',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Login')),
                        ButtonSegment(value: true, label: Text('Sign up')),
                      ],
                      selected: {_register},
                      onSelectionChanged: (s) => setState(() {
                        _register = s.first;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                      validator: (v) => v == null || v.trim().length < 10 ? 'Enter a valid phone number' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'At least 6 characters' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: badColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, style: const TextStyle(color: badColor)),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(_register ? 'Create account' : 'Login'),
                    ),
                    const SizedBox(height: 18),
                    const Text('Demo: 9000000003 / 123456',
                        textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
