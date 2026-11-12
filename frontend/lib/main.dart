import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'sign_in_dialog.dart';
import 'inspection_plan_page.dart';
import 'my_inspections_page.dart';
import 'finding_overview_page.dart';
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api',
);

void main() => runApp(const InspectionApp());

class Facility {
  const Facility({required this.id, required this.name});

  final int id;
  final String name;

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class InspectionApp extends StatefulWidget {
  const InspectionApp({super.key, this.client});

  final http.Client? client;

  @override
  State<InspectionApp> createState() => _InspectionAppState();
}

class _InspectionAppState extends State<InspectionApp> {
  late Future<List<Facility>> _facilities = _loadFacilities();
  DemoSession? _session;

  Future<void> _openSignIn(BuildContext pageContext) async {
    final session = await showDialog<DemoSession>(
      context: pageContext,
      barrierDismissible: false,
      builder: (_) => SignInDialog(
        apiBaseUrl: apiBaseUrl,
        client: widget.client,
      ),
    );

    if (!mounted || session == null) {
      return;
    }

    setState(() {
      _session = session;
    });
  }

  Future<List<Facility>> _loadFacilities() async {
    final getResponse = widget.client?.get ?? http.get;
    final response = await getResponse(
      Uri.parse('$apiBaseUrl/facilities'),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw StateError('API returned status ${response.statusCode}');
    }

    final rows = jsonDecode(response.body);
    if (rows is! List<dynamic>) {
      throw const FormatException('Expected a list of facilities');
    }

    return rows.map((row) {
      return Facility.fromJson(row as Map<String, dynamic>);
    }).toList();
  }

  void _retry() {
    setState(() {
      _facilities = _loadFacilities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Campus Facility Inspection Scheduler',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (session != null &&
                (session.role == 'supervisor' || session.role == 'maintenance'))
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FindingOverviewPage(
                          apiBaseUrl: apiBaseUrl,
                          token: session.token,
                          showCompliance: session.role == 'supervisor',
                          client: widget.client,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    session.role == 'supervisor' ? 'Alerts & Compliance' : 'Finding Alerts',
                  ),
                ),
              ),
            if (session != null && session.role == 'inspector')
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MyInspectionsPage(
                          apiBaseUrl: apiBaseUrl,
                          token: session.token,
                          client: widget.client,
                        ),
                      ),
                    );
                  },
                  child: const Text('My Inspections'),
                ),
              ),
            Builder(
              builder: (pageContext) => TextButton(
                onPressed: () => _openSignIn(pageContext),
                child: Text(session == null ? 'Sign in' : 'Switch account'),
              ),
            ),
          ],
          bottom: session == null
              ? null
              : PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Signed in as ${session.name} (${session.role})',
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Facility>>(
          future: _facilities,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load facilities.'),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final facilities = snapshot.data ?? const <Facility>[];
            if (facilities.isEmpty) {
              return const Center(child: Text('No facilities found.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final facility = facilities[index];
                return Card(
                  child: ListTile(
                    title: Text(facility.name),
                    subtitle: Text('Facility ID: ${facility.id}'),
                    trailing: session != null && session.role == 'supervisor'
                        ? TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => InspectionPlanPage(
                              apiBaseUrl: apiBaseUrl,
                              token: session.token,
                              facilityId: facility.id,
                              facilityName: facility.name,
                              client: widget.client,
                            ),
                          ),
                        );
                      },
                      child: const Text('New plan'),
                    )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}