import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InspectionChecklistPage extends StatefulWidget {
  const InspectionChecklistPage({
    super.key,
    required this.apiBaseUrl,
    required this.token,
    required this.inspectionId,
    required this.facilityName,
    this.client,
  });

  final String apiBaseUrl;
  final String token;
  final int inspectionId;
  final String facilityName;
  final http.Client? client;

  @override
  State<InspectionChecklistPage> createState() =>
      _InspectionChecklistPageState();
}

class _InspectionChecklistPageState extends State<InspectionChecklistPage> {
  static const _timeout = Duration(seconds: 8);
  static const _answerLabels = {'pass': 'Pass', 'fail': 'Fail'};

  late Future<_Checklist> _checklist;
  final _answers = <String, String>{};
  bool _saving = false;
  String? _saveError;

  Uri get _endpoint => Uri.parse(
    '${widget.apiBaseUrl}/inspections/${widget.inspectionId}/checklist',
  );

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _checklist = _loadChecklist();
  }

  Future<_Checklist> _loadChecklist() async {
    final getResponse = widget.client?.get ?? http.get;
    final response = await getResponse(
      _endpoint,
      headers: _headers,
    ).timeout(_timeout);

    return _readChecklist(response);
  }

  _Checklist _readChecklist(http.Response response) {
    final message = switch (response.statusCode) {
      200 => null,
      401 || 403 => 'Go back and sign in again as the inspector.',
      404 => 'This inspection is unavailable.',
      409 => 'A checklist was already saved. Use Refresh to see the saved answers.',
      422 => 'The server rejected these answers. Use Refresh and try again.',
      _ => 'The server returned HTTP ${response.statusCode}.',
    };
    if (message != null) {
      throw StateError(message);
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes))
    as Map<String, dynamic>;

    return _Checklist(
      status: json['status'] as String,
      items: Map<String, String>.from(json['items'] as Map<String, dynamic>),
      results: Map<String, String>.from(
        (json['results'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  void _refresh() {
    setState(() {
      _saveError = null;
      _checklist = _loadChecklist();
    });
  }

  Future<void> _submit(Iterable<String> keys) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final putResponse = widget.client?.put ?? http.put;
      final response = await putResponse(
        _endpoint,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'results': {for (final key in keys) key: _answers[key]},
        }),
      ).timeout(_timeout);

      final saved = _readChecklist(response);
      if (!mounted) return;

      setState(() {
        _checklist = Future<_Checklist>.value(saved);
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _saveError = error is StateError
            ? error.message
            : 'Could not confirm the save. Retry the same answers or use Refresh.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inspection #${widget.inspectionId} Checklist'),
        actions: [
          IconButton(
            tooltip: 'Refresh checklist',
            onPressed: _saving ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_Checklist>(
        future: _checklist,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = snapshot.error;
          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error is StateError
                      ? error.message
                      : 'Could not load the checklist. Use Refresh to try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final checklist = snapshot.requireData;
          final editable = checklist.status == 'scheduled';
          final ready = editable &&
              !_saving &&
              checklist.items.keys.every(_answers.containsKey);
          final saveError = _saveError;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.facilityName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(switch (checklist.status) {
                'scheduled' => 'Choose Pass or Fail for every item.',
                'completed' => 'Checklist completed',
                _ => checklist.status,
              }),
              const SizedBox(height: 12),
              for (final item in checklist.items.entries)
                Card(
                  child: ListTile(
                    title: Text(item.value),
                    trailing: editable
                        ? DropdownButton<String>(
                      value: _answers[item.key],
                      hint: const Text('Select'),
                      items: [
                        for (final answer in _answerLabels.entries)
                          DropdownMenuItem<String>(
                            value: answer.key,
                            child: Text(answer.value),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                        if (value == null) return;
                        setState(() {
                          _answers[item.key] = value;
                        });
                      },
                    )
                        : Text(_answerLabels[checklist.results[item.key]] ?? '—'),
                  ),
                ),
              if (editable) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: ready
                      ? () => _submit(checklist.items.keys)
                      : null,
                  child: Text(_saving ? 'Saving…' : 'Submit checklist'),
                ),
              ],
              if (saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(saveError),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Checklist {
  const _Checklist({
    required this.status,
    required this.items,
    required this.results,
  });

  final String status;
  final Map<String, String> items;
  final Map<String, String> results;
}