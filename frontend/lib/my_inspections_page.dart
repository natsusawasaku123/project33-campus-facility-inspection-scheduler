import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'inspection_checklist_page.dart';

class MyInspectionsPage extends StatefulWidget {
  const MyInspectionsPage({
    super.key,
    required this.apiBaseUrl,
    required this.token,
    this.client,
  });

  final String apiBaseUrl;
  final String token;
  final http.Client? client;

  @override
  State<MyInspectionsPage> createState() => _MyInspectionsPageState();
}

class _MyInspectionsPageState extends State<MyInspectionsPage> {
  late Future<List<_Inspection>> _inspections;

  @override
  void initState() {
    super.initState();
    _inspections = _loadInspections();
  }

  Future<List<_Inspection>> _loadInspections() async {
    final getResponse = widget.client?.get ?? http.get;
    final response = await getResponse(
      Uri.parse('${widget.apiBaseUrl}/inspections'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Go back and sign in again as the inspector.');
    }

    if (response.statusCode != 200) {
      throw StateError('The server returned HTTP ${response.statusCode}.');
    }

    final rows = jsonDecode(utf8.decode(response.bodyBytes));
    if (rows is! List<dynamic>) {
      throw const FormatException('Expected an inspection list');
    }

    return rows
        .map((row) => _Inspection.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  void _refresh() {
    setState(() {
      _inspections = _loadInspections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Inspections'),
        actions: [
          IconButton(
            tooltip: 'Refresh inspections',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<_Inspection>>(
        future: _inspections,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = snapshot.error;
          if (error != null) {
            final message = error is StateError
                ? error.message
                : 'Could not load inspections. Use Refresh to try again.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(message, textAlign: TextAlign.center),
              ),
            );
          }

          final inspections = snapshot.data ?? const <_Inspection>[];
          if (inspections.isEmpty) {
            return const Center(child: Text('No inspections assigned.'));
          }

          final localizations = MaterialLocalizations.of(context);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: inspections.length,
            itemBuilder: (context, index) {
              final inspection = inspections[index];
              final date = localizations.formatShortDate(inspection.scheduledAt);
              final time = localizations.formatTimeOfDay(
                TimeOfDay.fromDateTime(inspection.scheduledAt),
              );

              return Card(
                child: ListTile(
                  title: Text(inspection.facilityName),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => InspectionChecklistPage(
                          apiBaseUrl: widget.apiBaseUrl,
                          token: widget.token,
                          inspectionId: inspection.id,
                          facilityName: inspection.facilityName,
                          client: widget.client,
                        ),
                      ),
                    );

                    if (mounted) _refresh();
                  },
                  subtitle: Text('Inspection #${inspection.id}\n$date at $time'),
                  isThreeLine: true,
                  trailing: Text(inspection.status),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Inspection {
  const _Inspection({
    required this.id,
    required this.facilityName,
    required this.scheduledAt,
    required this.status,
  });

  factory _Inspection.fromJson(Map<String, dynamic> json) {
    return _Inspection(
      id: json['id'] as int,
      facilityName: json['facility_name'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      status: json['status'] as String,
    );
  }

  final int id;
  final String facilityName;
  final DateTime scheduledAt;
  final String status;
}