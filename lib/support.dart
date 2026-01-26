import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/setup.dart' show userEmail;
import 'package:LegisTracerEU/preparehtml.dart' show server;
import 'package:LegisTracerEU/main.dart' show jsonSettings;

class SupportForm extends StatefulWidget {
  const SupportForm({Key? key}) : super(key: key);

  @override
  _SupportFormState createState() => _SupportFormState();
}

class _SupportFormState extends State<SupportForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _includeSystemInfo = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = userEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String message = _messageController.text;

      // Append system info if requested
      if (_includeSystemInfo) {
        final info = await PackageInfo.fromPlatform();
        final appVersion = info.version;
        final os = Platform.operatingSystem;
        final osVersion = Platform.operatingSystemVersion;

        // Read last ~2000 chars of log
        final logManager = const LogManager();
        final fullLog = await logManager.readLogs();
        final snippet =
            fullLog.length > 2000
                ? fullLog.substring(fullLog.length - 2000)
                : fullLog;

        message +=
            '\n\n--- System Information ---\n'
            'App version: $appVersion\n'
            'OS: $os $osVersion\n'
            'User email used for access: ${_emailController.text}\n\n'
            'Recent log tail:\n'
            '----------------\n'
            '$snippet';
      }

      // Submit to server endpoint
      final response = await http
          .post(
            Uri.parse('$server/support'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': jsonSettings['access_key'] ?? '',
            },
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'subject': _subjectController.text.trim(),
              'message': message,
              'apiKey': jsonSettings['access_key'] ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      setState(() => _isSubmitting = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear form
        _subjectController.clear();
        _messageController.clear();
      } else {
        final error = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error['message'] ?? response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Contact Support',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please describe your issue below. We\'ll respond to your email address.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Your Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Subject is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Message is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _includeSystemInfo,
                onChanged: (value) {
                  setState(() => _includeSystemInfo = value ?? true);
                },
                title: const Text('Include system information and logs'),
                subtitle: const Text(
                  'Helps us diagnose issues faster',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text(
                          'Submit Support Request',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: You can submit up to 5 support requests per day.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Legacy function for backward compatibility
Future<void> reportProblem() async {
  // This function is deprecated - use SupportForm widget instead
  throw UnimplementedError('Use SupportForm widget instead');
}
