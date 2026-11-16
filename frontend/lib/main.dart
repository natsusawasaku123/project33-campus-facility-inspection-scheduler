import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'campus_theme.dart';
import 'campus_dashboard.dart';
import 'dashboard_data.dart';
import 'finding_overview_page.dart';
import 'inspection_plan_page.dart';
import 'my_inspections_page.dart';
import 'secure_api_client.dart';
import 'sign_in_dialog.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://localhost:8443/api',
);
const _allowInsecureLoopback = bool.fromEnvironment('ALLOW_INSECURE_LOOPBACK');

void main() => runApp(const InspectionApp());

class InspectionApp extends StatefulWidget {
  const InspectionApp({super.key, this.client});
  final http.Client? client;
  @override
  State<InspectionApp> createState() => _InspectionAppState();
}

class _InspectionAppState extends State<InspectionApp> {
  final _navigator = GlobalKey<NavigatorState>();
  SecureApiClient? _client;
  late Future<List<Facility>> _facilities;
  DemoSession? _session;
  Timer? _expiry;
  bool _signingOut = false;
  bool _dark = false;
  Future<DashboardActivity>? _activity;
  String? _notice;

  @override
  void initState() {
    super.initState();
    try {
      _client = SecureApiClient(
        baseUrl: apiBaseUrl,
        inner: widget.client,
        allowInsecureLoopback: _allowInsecureLoopback,
        onUnauthorized: _expireSession,
      );
    } on FormatException {
      _notice = 'The secure connection is not configured. Contact your administrator.';
    }
    _facilities = _loadFacilities();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _client?.close();
    super.dispose();
  }

  void _expireSession() {
    if (!mounted || _session == null) return;
    _expiry?.cancel();
    _navigator.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _session = null;
      _activity = null;
      _notice = 'Your session has ended. Sign in again to continue.';
    });
  }

  Future<bool> _signOut() async {
    final session = _session;
    if (session == null) return true;
    if (_signingOut) return false;
    setState(() => _signingOut = true);
    try {
      final response = await _client!
          .post(
            Uri.parse('$apiBaseUrl/auth/logout'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 204 && response.statusCode != 401) {
        throw const FormatException('Sign out not confirmed');
      }
      if (!mounted) return true;
      _expiry?.cancel();
      setState(() {
        _session = null;
        _activity = null;
        _notice = 'You have signed out.';
      });
      return true;
    } on Exception {
      if (mounted) {
        setState(
          () => _notice = 'Could not confirm sign out. Please try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _openSignIn(BuildContext context) async {
    if (_client == null) return;
    if (_session != null && !await _signOut()) return;
    if (!context.mounted) return;
    final session = await showDialog<DemoSession>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignInDialog(apiBaseUrl: apiBaseUrl, client: _client),
    );
    if (!mounted || session == null) return;
    setState(() {
      _session = session;
      _activity = _loadActivity(session);
      _notice = null;
    });
    _expiry?.cancel();
    _expiry = Timer(
      session.expiresAt.difference(DateTime.now()),
      _expireSession,
    );
  }

  Future<List<Facility>> _loadFacilities() async {
    final client = _client;
    if (client == null) {
      throw StateError('Secure connection is not configured.');
    }
    final response = await client
        .get(
          Uri.parse('$apiBaseUrl/facilities'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Could not load facilities.');
    }
    final rows = jsonDecode(utf8.decode(response.bodyBytes));
    if (rows is! List<dynamic>) {
      throw const FormatException('Invalid facility list');
    }
    return rows
        .map((row) => Facility.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  void _open(Widget page) {
    _navigator.currentState!.popUntil((route) => route.isFirst);
    _navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<DashboardActivity> _loadActivity(DemoSession session) {
    final future = DashboardActivity.load(
      client: _client!,
      baseUrl: apiBaseUrl,
      role: session.role,
      token: session.token,
    );
    // The dialog can close before the next frame attaches the FutureBuilder.
    // Observe errors immediately; the same future still delivers them to the UI.
    future.ignore();
    return future;
  }

  void _refresh() => setState(() {
    _facilities = _loadFacilities();
    if (_session != null) _activity = _loadActivity(_session!);
  });

  void _refreshActivity() {
    final session = _session;
    if (session != null) {
      setState(() {
        _activity = _loadActivity(session);
      });
    }
  }

  void _openTool(CampusTool tool) {
    final session = _session;
    if (session == null) return;
    if (tool == CampusTool.inspections && session.role == 'inspector') {
      _open(
        MyInspectionsPage(
          apiBaseUrl: apiBaseUrl,
          token: session.token,
          client: _client,
        ),
      );
    } else if (tool == CampusTool.alerts &&
        (session.role == 'supervisor' || session.role == 'maintenance')) {
      _open(
        FindingOverviewPage(
          apiBaseUrl: apiBaseUrl,
          token: session.token,
          showCompliance: session.role == 'supervisor',
          client: _client,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Campus Facility Inspection Scheduler',
    debugShowCheckedModeBanner: false,
    theme: campusTheme(),
    darkTheme: campusTheme(brightness: Brightness.dark),
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    navigatorKey: _navigator,
    home: Builder(
      builder: (context) => CampusDashboard(
        facilities: _facilities,
        activity: _activity,
        name: _session?.name,
        role: _session?.role,
        notice: _notice,
        signingOut: _signingOut,
        canSignIn: _client != null,
        onSignIn: () => _openSignIn(context),
        onSignOut: () => _signOut(),
        onRefresh: _refresh,
        onRefreshActivity: _refreshActivity,
        onToggleTheme: () => setState(() => _dark = !_dark),
        onOpenTool: _openTool,
        onCreatePlan: (facility) {
          final session = _session;
          if (session?.role != 'supervisor') return;
          _open(
            InspectionPlanPage(
              apiBaseUrl: apiBaseUrl,
              token: session!.token,
              facilityId: facility.id,
              facilityName: facility.name,
              client: _client,
            ),
          );
        },
      ),
    ),
  );
}
