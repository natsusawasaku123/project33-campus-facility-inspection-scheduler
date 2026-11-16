import 'dart:convert';

import 'package:http/http.dart' as http;

class Facility {
  const Facility({required this.id, required this.name});
  final int id;
  final String name;
  factory Facility.fromJson(Map<String, dynamic> json) =>
      Facility(id: json['id'] as int, name: json['name'] as String);
}

class CampusEvent {
  const CampusEvent({
    required this.title,
    required this.detail,
    required this.date,
    required this.completed,
  });
  final String title, detail;
  final DateTime date;
  final bool completed;
}

class DashboardActivity {
  const DashboardActivity({
    this.scheduled,
    this.completed,
    this.openFindings,
    this.alertCount,
    this.totalAssigned,
    this.reportDate,
    this.timezone,
    this.events = const [],
  });
  final int? scheduled, completed, openFindings, alertCount, totalAssigned;
  final DateTime? reportDate;
  final String? timezone;
  final List<CampusEvent> events;
  double? get progress => scheduled == null || scheduled == 0
      ? null
      : (completed! / scheduled!).clamp(0, 1);

  static Future<DashboardActivity> load({
    required http.Client client,
    required String baseUrl,
    required String role,
    required String token,
  }) async {
    Future<dynamic> get(String path) async {
      final response = await client
          .get(
            Uri.parse('$baseUrl/$path'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('Could not load your activity.');
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    List<CampusEvent> alerts(dynamic data) =>
        (data as List<dynamic>).map((item) {
          final row = item as Map<String, dynamic>;
          return CampusEvent(
            title: row['facility_name'] as String,
            detail: row['description'] as String,
            date: DateTime.parse(row['due_at'] as String).toLocal(),
            completed: false,
          );
        }).toList()..sort((a, b) => a.date.compareTo(b.date));
    if (role == 'supervisor') {
      final responses = await Future.wait([
        get('compliance-summary'),
        get('finding-alerts'),
      ]);
      final summary = responses[0] as Map<String, dynamic>;
      final events = alerts(responses[1]);
      return DashboardActivity(
        scheduled: summary['inspections_scheduled'] as int,
        completed: summary['inspections_completed'] as int,
        openFindings: summary['open_findings'] as int,
        alertCount: events.length,
        reportDate: DateTime.parse(summary['date'] as String),
        timezone: summary['timezone'] as String,
        events: events,
      );
    }
    if (role == 'inspector') {
      final data = await get('inspections') as List<dynamic>;
      final events = data.map((item) {
        final row = item as Map<String, dynamic>;
        return CampusEvent(
          title: row['facility_name'] as String,
          detail: 'Inspection #${row['id']}',
          date: DateTime.parse(row['scheduled_at'] as String).toLocal(),
          completed: row['status'] == 'completed',
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
      final now = DateTime.now();
      final today = events.where(
        (e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day,
      );
      return DashboardActivity(
        scheduled: today.length,
        completed: today.where((e) => e.completed).length,
        totalAssigned: events.length,
        reportDate: now,
        timezone: 'Local time',
        events: events,
      );
    }
    if (role == 'maintenance') {
      final events = alerts(await get('finding-alerts'));
      return DashboardActivity(alertCount: events.length, events: events);
    }
    return const DashboardActivity();
  }
}
