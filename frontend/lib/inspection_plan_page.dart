import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InspectionPlanPage extends StatefulWidget {
  const InspectionPlanPage({
    super.key,
    required this.apiBaseUrl,
    required this.token,
    required this.facilityId,
    required this.facilityName,
    this.client,
  });

  final String apiBaseUrl;
  final String token;
  final int facilityId;
  final String facilityName;
  final http.Client? client;

  @override
  State<InspectionPlanPage> createState() => _InspectionPlanPageState();
}

class _Inspector {
  const _Inspector(this.id, this.name);

  final int id;
  final String name;
}

class _InspectionPlanPageState extends State<InspectionPlanPage> {
  static const _timeout = Duration(seconds: 8);
  static const _uncertainSave =
      'Could not confirm the save. Check the plans table before submitting again.';

  final _formKey = GlobalKey<FormState>();
  final _dueLabel = TextEditingController();
  final _repeatDays = TextEditingController(text: '1');

  late Future<List<_Inspector>> _inspectors = _loadInspectors();

  int? _inspectorId;
  DateTime? _firstDueAt;
  int? _savedPlanId;
  String? _error;
  bool _saving = false;
  bool _needsSaveCheck = false;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  String _statusMessage(int status, String fallback) {
    return switch (status) {
      401 => 'Go back and use Switch account to sign in again.',
      403 => 'Only supervisors can create inspection plans.',
      422 => 'Check the selected inspector, future date, and repeat interval.',
      _ => fallback,
    };
  }

  Future<List<_Inspector>> _loadInspectors() async {
    final getResponse = widget.client?.get ?? http.get;
    final response = await getResponse(
      Uri.parse('${widget.apiBaseUrl}/inspectors'),
      headers: _headers,
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw StateError(
        _statusMessage(response.statusCode, 'Could not load inspectors.'),
      );
    }

    final rows = jsonDecode(response.body);
    if (rows is! List<dynamic>) {
      throw const FormatException('Invalid inspector list');
    }

    return rows.map((item) {
      final row = item as Map<String, dynamic>;
      return _Inspector(row['id'] as int, row['name'] as String);
    }).toList();
  }

  Future<void> _chooseDueTime() async {
    final now = DateTime.now();
    final suggested = now.add(const Duration(minutes: 10));

    final day = await showDatePicker(
      context: context,
      initialDate: suggested,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (!mounted || day == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(suggested),
    );
    if (!mounted || time == null) return;

    final dueAt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(dueAt);
    final timeLabel = time.format(context);

    setState(() {
      _firstDueAt = dueAt;
      _dueLabel.text = '$dateLabel, $timeLabel';
    });
  }

  Future<void> _savePlan() async {
    if (_saving || _needsSaveCheck || _savedPlanId != null) return;
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    int? savedId;
    String? message;
    bool needsCheck = false;

    try {
      final postResponse = widget.client?.post ?? http.post;
      final response = await postResponse(
        Uri.parse('${widget.apiBaseUrl}/plans'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'facility_id': widget.facilityId,
          'inspector_id': _inspectorId,
          'first_due_at': _firstDueAt!.toUtc().toIso8601String(),
          'repeat_days': int.parse(_repeatDays.text.trim()),
        }),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic> || data['id'] is! int) {
          throw const FormatException('Missing saved plan ID');
        }
        savedId = data['id'] as int;
      } else {
        needsCheck = response.statusCode >= 500;
        message = _statusMessage(
          response.statusCode,
          needsCheck ? _uncertainSave : 'Laravel could not save the plan.',
        );
      }
    } on Exception {
      needsCheck = true;
      message = _uncertainSave;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedPlanId = savedId;
      _error = message;
      _needsSaveCheck = needsCheck;
    });
  }

  @override
  void dispose() {
    _dueLabel.dispose();
    _repeatDays.dispose();
    super.dispose();
  }

  Widget _buildForm(List<_Inspector> inspectors) {
    final savedPlanId = _savedPlanId;
    final locked = _saving || savedPlanId != null || _needsSaveCheck;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.facilityName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Inspector'),
            isExpanded: true,
            items: inspectors.map((inspector) {
              return DropdownMenuItem(
                value: inspector.id,
                child: Text(inspector.name),
              );
            }).toList(),
            onChanged: locked ? null : (id) => _inspectorId = id,
            validator: (id) => id == null ? 'Choose an inspector.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dueLabel,
            readOnly: true,
            enabled: !locked,
            onTap: _chooseDueTime,
            decoration: const InputDecoration(
              labelText: 'First inspection (local time)',
              hintText: 'Choose a date and time',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            validator: (_) {
              final dueAt = _firstDueAt;
              if (dueAt == null || !dueAt.isAfter(DateTime.now())) {
                return 'Choose a future date and time.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _repeatDays,
            enabled: !locked,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Repeat every (days)'),
            validator: (value) {
              final days = int.tryParse(value?.trim() ?? '');
              if (days == null || days < 1 || days > 365) {
                return 'Enter a whole number from 1 to 365.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (savedPlanId != null) ...[
            Text(
              'Plan #$savedPlanId saved',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ] else
            FilledButton(
              onPressed: locked ? null : _savePlan,
              child: Text(_saving ? 'Saving…' : 'Save plan'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Inspection Plan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder<List<_Inspector>>(
            future: _inspectors,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              final inspectors = snapshot.data ?? const <_Inspector>[];
              if (snapshot.hasError || inspectors.isEmpty) {
                final error = snapshot.error;
                final message = error is StateError
                    ? error.message
                    : snapshot.hasError
                    ? 'Could not load inspectors. Check Laravel and retry.'
                    : 'No inspectors are available.';

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(message),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _inspectors = _loadInspectors());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }

              return _buildForm(inspectors);
            },
          ),
        ),
      ),
    );
  }
}