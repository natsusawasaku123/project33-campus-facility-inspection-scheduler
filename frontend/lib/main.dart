import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'campus_theme.dart';
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

class Facility {
  const Facility({required this.id, required this.name});
  final int id;
  final String name;
  factory Facility.fromJson(Map<String, dynamic> json) =>
      Facility(id: json['id'] as int, name: json['name'] as String);
}

class InspectionApp extends StatefulWidget {
  const InspectionApp({super.key, this.client});
  final http.Client? client;
  @override
  State<InspectionApp> createState() => _InspectionAppState();
}

class _InspectionAppState extends State<InspectionApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _scaffold = GlobalKey<ScaffoldState>();
  SecureApiClient? _client;
  late Future<List<Facility>> _facilities;
  DemoSession? _session;
  Timer? _expiry;
  bool _signingOut = false;
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
    _scaffold.currentState?.closeDrawer();
    _navigator.currentState!.popUntil((route) => route.isFirst);
    _navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _brand() => const Row(
    children: [
      CircleAvatar(
        backgroundColor: Color(0xFFEEEAFD),
        foregroundColor: campusPurple,
        child: Icon(Icons.domain_rounded),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAMPUS',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Facility inspections',
              style: TextStyle(fontSize: 14, color: Color(0xFF647089)),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _navigation() {
    final session = _session;
    return <Widget>[
      ListTile(
        selected: true,
        selectedTileColor: const Color(0xFFEEEAFD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.grid_view_rounded),
        title: const Text('Facilities'),
        onTap: () {
          _scaffold.currentState?.closeDrawer();
          _navigator.currentState?.popUntil((route) => route.isFirst);
        },
      ),
      if (session?.role == 'inspector')
        ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('My Inspections'),
          onTap: () => _open(
            MyInspectionsPage(
              apiBaseUrl: apiBaseUrl,
              token: session!.token,
              client: _client,
            ),
          ),
        ),
      if (session?.role == 'supervisor' || session?.role == 'maintenance')
        ListTile(
          leading: const Icon(Icons.notifications_none_rounded),
          title: Text(
            session!.role == 'supervisor'
                ? 'Alerts & Compliance'
                : 'Finding Alerts',
          ),
          onTap: () => _open(
            FindingOverviewPage(
              apiBaseUrl: apiBaseUrl,
              token: session.token,
              showCompliance: session.role == 'supervisor',
              client: _client,
            ),
          ),
        ),
    ].map((item) => Material(color: Colors.transparent, child: item)).toList();
  }

  Widget _statePanel(
    IconData icon,
    String title,
    String detail, {
    VoidCallback? retry,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: campusPurple),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          if (retry != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _facilityCard(Facility facility) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEAF2FC),
            foregroundColor: Color(0xFF3264A0),
            child: Icon(Icons.meeting_room_outlined),
          ),
          const SizedBox(height: 20),
          Text(
            facility.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: campusNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Facility ID: ${facility.id}',
            style: const TextStyle(color: Color(0xFF647089)),
          ),
          const SizedBox(height: 24),
          if (_session?.role == 'supervisor')
            FilledButton.icon(
              onPressed: () => _open(
                InspectionPlanPage(
                  apiBaseUrl: apiBaseUrl,
                  token: _session!.token,
                  facilityId: facility.id,
                  facilityName: facility.name,
                  client: _client,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New plan'),
            )
          else
            Text(
              _session == null
                  ? 'Sign in to access your inspection tools.'
                  : 'Open your assigned tools from navigation.',
              style: const TextStyle(color: Color(0xFF647089), height: 1.5),
            ),
        ],
      ),
    ),
  );

  Widget _dashboard(BuildContext context, bool wide) => ListView(
    padding: EdgeInsets.all(wide ? 36 : 20),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your campus, cared for.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: campusNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Plan inspections. Follow up on findings. Keep everyone moving safely.',
                style: TextStyle(color: Color(0xFF647089), height: 1.5),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [campusNavy, campusPurple],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFFDBD6FF),
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _session == null
                          ? 'A safer campus starts with one inspection.'
                          : 'Welcome back, ${_session!.name}.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _session == null
                          ? 'Sign in with your assigned account to plan inspections or review your tasks.'
                          : 'Signed in as ${_session!.role}. Your available tools appear in navigation.',
                      style: const TextStyle(
                        color: Color(0xFFE5E0FF),
                        height: 1.5,
                      ),
                    ),
                    if (_session == null) ...[
                      const SizedBox(height: 20),
                      FilledButton.tonalIcon(
                        onPressed: _client == null
                            ? null
                            : () => _openSignIn(context),
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in'),
                      ),
                    ],
                  ],
                ),
              ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_notice!),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              const Text(
                'Campus facilities',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: campusNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find a facility and take the next step in its inspection workflow.',
                style: TextStyle(color: Color(0xFF647089), height: 1.5),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Facility>>(
                future: _facilities,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading facilities…'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _statePanel(
                      Icons.cloud_off_outlined,
                      'Could not load facilities.',
                      'Check your connection, then try again.',
                      retry: () => setState(() {
                        _facilities = _loadFacilities();
                      }),
                    );
                  }
                  final rows = snapshot.data ?? const <Facility>[];
                  if (rows.isEmpty) {
                    return _statePanel(
                      Icons.meeting_room_outlined,
                      'No facilities found.',
                      'Facilities will appear here when they are available.',
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, box) {
                      final columns = box.maxWidth >= 760
                          ? 3
                          : box.maxWidth >= 500
                          ? 2
                          : 1;
                      final width =
                          (box.maxWidth - 18 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          for (final facility in rows)
                            SizedBox(
                              width: width,
                              child: _facilityCard(facility),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 36),
              const Text(
                'University of La Salette · Campus Facility Inspection Scheduler',
                style: TextStyle(color: Color(0xFF647089), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Campus Facility Inspection Scheduler',
    debugShowCheckedModeBanner: false,
    theme: campusTheme(),
    navigatorKey: _navigator,
    home: LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        return Scaffold(
          key: _scaffold,
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _brand(),
                          const SizedBox(height: 28),
                          ..._navigation(),
                        ],
                      ),
                    ),
                  ),
                ),
          appBar: AppBar(
            title: Text(
              wide ? 'Facility Inspection Scheduler' : 'Campus inspections',
            ),
            actions: [
              TextButton(
                onPressed: _client == null || _signingOut
                    ? null
                    : () => _openSignIn(context),
                child: Text(_session == null ? 'Sign in' : 'Switch account'),
              ),
              if (_session != null)
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _signingOut ? null : _signOut,
                  icon: const Icon(Icons.logout),
                ),
              const SizedBox(width: 12),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                Container(
                  width: 250,
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _brand(),
                      const SizedBox(height: 36),
                      const Text(
                        'WORKSPACE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Color(0xFF647089),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._navigation(),
                      const Spacer(),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        _session == null
                            ? 'Ready when you are.'
                            : '${_session!.name}\n${_session!.role}',
                        style: const TextStyle(
                          color: Color(0xFF647089),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _dashboard(context, wide)),
            ],
          ),
        );
      },
    ),
  );
}
