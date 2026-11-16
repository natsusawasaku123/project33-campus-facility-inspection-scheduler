import 'dart:convert';

import 'package:campus_facility_inspection_scheduler/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> signIn(WidgetTester tester, String role) async {
  await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).at(0),
    '$role@example.test',
  );
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'test-password-only',
  );
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Sign in'),
    ),
  );
  await tester.pumpAndSettle();
}

http.Response login(String role) => http.Response(
  jsonEncode({
    'token': 'test-token-only',
    'expires_at': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'user': {'id': 2, 'name': 'Demo $role', 'role': role},
  }),
  200,
);

void main() {
  testWidgets('facility search and theme switching preserve loaded data', (
    tester,
  ) async {
    desktop(tester);
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(
        '[{"id":1,"name":"Demo Science Room"},{"id":2,"name":"Library"}]',
        200,
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(InspectionApp(client: client));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('facility-search')),
      'library',
    );
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Demo Science Room'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.text('Library'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('facility-search')),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching facilities.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Science Room'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inspector calendar uses assigned records and clears private activity on logout',
    (tester) async {
      desktop(tester);
      final now = DateUtils.dateOnly(DateTime.now());
      final tomorrow = now.add(const Duration(days: 1));
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/facilities')) {
          return http.Response('[{"id":1,"name":"Demo Science Room"}]', 200);
        }
        if (request.url.path.endsWith('/auth/login')) return login('inspector');
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/inspections')) {
          expect(request.headers['Authorization'], 'Bearer test-token-only');
          return http.Response(
            jsonEncode([
              {
                'id': 41,
                'facility_name': 'Demo Science Room',
                'scheduled_at': now.toIso8601String(),
                'status': 'completed',
              },
              {
                'id': 42,
                'facility_name': 'Demo Science Room',
                'scheduled_at': now.toIso8601String(),
                'status': 'scheduled',
              },
              {
                'id': 43,
                'facility_name': 'Engineering Hall',
                'scheduled_at': tomorrow.toIso8601String(),
                'status': 'scheduled',
              },
            ]),
            200,
          );
        }
        throw StateError('Unexpected request: ${request.url.path}');
      });
      addTearDown(client.close);
      await tester.pumpWidget(InspectionApp(client: client));
      await tester.pumpAndSettle();
      await signIn(tester, 'inspector');
      expect(find.text('50%'), findsOneWidget);
      final strings = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      if (tomorrow.month != now.month) {
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip(strings.formatFullDate(tomorrow)));
      await tester.pumpAndSettle();
      expect(find.text('Engineering Hall'), findsOneWidget);
      expect(
        paths.any(
          (path) =>
              path.endsWith('/compliance-summary') ||
              path.endsWith('/finding-alerts'),
        ),
        isFalse,
      );
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Engineering Hall'), findsNothing);
      expect(find.text('50%'), findsNothing);
      expect(find.text('You have signed out.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'activity failure offers a retry without inventing zero metrics',
    (tester) async {
      desktop(tester);
      var summaries = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/facilities')) {
          return http.Response('[]', 200);
        }
        if (request.url.path.endsWith('/auth/login')) {
          return login('supervisor');
        }
        if (request.url.path.endsWith('/finding-alerts')) {
          return http.Response('[]', 200);
        }
        if (request.url.path.endsWith('/compliance-summary')) {
          if (++summaries == 1) return http.Response('{}', 503);
          return http.Response(
            jsonEncode({
              'date': '2026-11-17',
              'timezone': 'Asia/Manila',
              'inspections_scheduled': 4,
              'inspections_completed': 3,
              'open_findings': 2,
            }),
            200,
          );
        }
        throw StateError('Unexpected request');
      });
      addTearDown(client.close);
      await tester.pumpWidget(InspectionApp(client: client));
      await tester.pumpAndSettle();
      await signIn(tester, 'supervisor');
      expect(find.text('Could not load your activity.'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      await tester.ensureVisible(find.text('Retry activity'));
      await tester.tap(find.text('Retry activity'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load your activity.'), findsNothing);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3 of 4 inspections completed'), findsOneWidget);
      expect(summaries, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
