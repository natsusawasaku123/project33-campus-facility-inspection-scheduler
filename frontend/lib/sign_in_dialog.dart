import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DemoSession {
  const DemoSession({
    required this.token,
    required this.name,
    required this.role,
  });

  final String token;
  final String name;
  final String role;

  factory DemoSession.fromResponse(String body) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid sign-in response');
    }

    final token = data['token'];
    final user = data['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const FormatException('Missing sign-in details');
    }

    final name = user['name'];
    final role = user['role'];
    if (name is! String || role is! String) {
      throw const FormatException('Invalid account details');
    }

    return DemoSession(token: token, name: name, role: role);
  }
}

class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key, required this.apiBaseUrl, this.client});

  final String apiBaseUrl;
  final http.Client? client;

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    DemoSession? session;
    String? message;

    try {
      final post = widget.client?.post ?? http.post;
      final response = await post(
        Uri.parse('${widget.apiBaseUrl}/auth/login'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _email.text.trim(),
          'password': _password.text,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        session = DemoSession.fromResponse(response.body);
      } else {
        message = switch (response.statusCode) {
          401 => 'The email or password is incorrect.',
          403 => 'This account needs a role.',
          422 => 'Check the email and password fields.',
          429 => 'Too many attempts. Wait a minute and try again.',
          _ => 'The server could not sign you in. Try again.',
        };
      }
    } on TimeoutException {
      message = 'The sign-in request timed out. Try again.';
    } on http.ClientException {
      message = 'Could not reach Laravel. Check that the server is running.';
    } on FormatException {
      message = 'The API returned an unreadable sign-in response.';
    }

    if (!mounted) return;

    if (session != null) {
      Navigator.of(context).pop(session);
      return;
    }

    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Demo email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty || email.length > 255) {
                    return 'Enter a demo email of up to 255 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty || value.length > 64) {
                    return 'Enter a password of up to 64 characters.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: Text(_busy ? 'Signing in…' : 'Sign in'),
        ),
      ],
    );
  }
}