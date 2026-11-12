import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FindingOverviewPage extends StatefulWidget {
  const FindingOverviewPage({
    super.key,
    required this.apiBaseUrl,
    required this.token,
    required this.showCompliance,
    this.client,
  });

  final String apiBaseUrl;
  final String token;
  final bool showCompliance;
  final http.Client? client;

  @override
  State<FindingOverviewPage> createState() => _FindingOverviewPageState();
}

class _FindingOverviewPageState extends State<FindingOverviewPage> {
  late Future<List<Map<String, dynamic>>> _alerts;
  Future<Map<String, dynamic>>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _alerts = _loadAlerts();
    _summary = widget.showCompliance
        ? _getJson<Map<String, dynamic>>('compliance-summary')
        : null;
  }

  Future<List<Map<String, dynamic>>> _loadAlerts() async {
    final rows = await _getJson<List<dynamic>>('finding-alerts');
    return rows.map((row) => row as Map<String, dynamic>).toList();
  }

  Future<T> _getJson<T>(String path) async {
    final getResponse = widget.client?.get ?? http.get;
    final response = await getResponse(
      Uri.parse('${widget.apiBaseUrl}/$path'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Go back and sign in again with the correct account.');
    }
    if (response.statusCode != 200) {
      throw StateError('The server returned HTTP ${response.statusCode}.');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as T;
  }

  Widget _section<T>(Future<T> future, Widget Function(T) content) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final error = snapshot.error;
        if (error != null) {
          return Text(
            error is StateError
                ? error.message
                : 'Could not load this section. Use Refresh to try again.',
          );
        }

        return content(snapshot.requireData);
      },
    );
  }

  String _localTime(String value) {
    final dateTime = DateTime.parse(value).toLocal();
    final strings = MaterialLocalizations.of(context);
    final date = strings.formatShortDate(dateTime);
    final time = strings.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
    return '$date at $time';
  }

  Widget _summaryCard(Map<String, dynamic> summary) {
    final percent = summary['completion_percent'] as num?;
    final completion = percent == null
        ? 'No inspections scheduled for this date'
        : '${percent.toStringAsFixed(1)}% complete';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compliance Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${summary['date']} · ${summary['timezone']}'),
            const SizedBox(height: 8),
            Text(
              '${summary['inspections_completed']} of '
                  '${summary['inspections_scheduled']} scheduled inspections completed',
            ),
            Text(completion),
            const SizedBox(height: 8),
            const Text('Current findings'),
            Text(
              '${summary['open_findings']} open · '
                  '${summary['overdue_findings']} overdue · '
                  '${summary['escalated_open_findings']} escalated',
            ),
            Text('${summary['manual_review_alerts']} alerts need human review'),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final heading = switch ((alert['status'], alert['kind'])) {
      ('manual_review', _) => 'Needs human review',
      (_, 'escalation') => 'Supervisor escalation',
      _ => 'Overdue alert',
    };
    final action = alert['review_action'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$heading · Finding #${alert['finding_id']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${alert['facility_name']} · ${alert['description']}'),
            Text('Due ${_localTime(alert['due_at'] as String)}'),
            if (action != null) ...[
              Text('Reason ${alert['error_code']}'),
              Text(action),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alertList(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) return const Text('No finding alerts.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final alert in alerts) _alertCard(alert)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showCompliance ? 'Alerts & Compliance' : 'Finding Alerts',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (summary != null) ...[
            _section(summary, _summaryCard),
            const SizedBox(height: 16),
          ],
          Text('Finding Alerts', style: Theme.of(context).textTheme.titleLarge),
          _section(_alerts, _alertList),
        ],
      ),
    );
  }
}