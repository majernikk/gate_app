// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  bool _obscurePass = true;

  @override
  void dispose() {
    _username.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    final ok = await auth.login(_username.text, _pass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Zlé prihlasovacie údaje.';
    });
    // Netreba navigovať – GoRouter redirect nás presmeruje sám.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Prihlásenie', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Meno'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zadaj meno' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      decoration: InputDecoration(
                        labelText: 'Heslo',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      obscureText: _obscurePass,
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min. 6 znakov' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Prihlásiť sa'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
