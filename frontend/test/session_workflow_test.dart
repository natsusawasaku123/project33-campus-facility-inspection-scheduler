import 'dart:convert';

import 'package:campus_facility_inspection_scheduler/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'supervisor signs in, sees permitted actions and signs out through the API',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var revoked = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/facilities')) {
          return http.Response('[{"id":1,"name":"Demo Science Room"}]', 200);
        }
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'test-only',
              'expires_at': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'user': {
                'id': 1,
                'name': 'Demo Supervisor',
                'role': 'supervisor',
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/auth/logout')) {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer test-only');
          revoked = true;
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/compliance-summary')) {
          return http.Response(
            jsonEncode({
              'date': '2026-11-17',
              'timezone': 'Asia/Manila',
              'inspections_scheduled': 0,
              'inspections_completed': 0,
              'open_findings': 0,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/finding-alerts')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 404);
      });
      addTearDown(client.close);
      await tester.pumpWidget(InspectionApp(client: client));
      await tester.pumpAndSettle();
      expect(find.text('New plan'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'supervisor@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test-only-password',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Sign in'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New plan'), findsOneWidget);
      expect(find.text('Alerts & Compliance'), findsOneWidget);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(revoked, isTrue);
      expect(find.text('New plan'), findsNothing);
      expect(find.text('You have signed out.'), findsOneWidget);
    },
  );

  testWidgets(
    'failed facility request can be retried and empty state is clear',
    (tester) async {
      var attempts = 0;
      final client = MockClient(
        (request) async => ++attempts == 1
            ? http.Response('{}', 500)
            : http.Response('[]', 200),
      );
      addTearDown(client.close);
      await tester.pumpWidget(InspectionApp(client: client));
      await tester.pumpAndSettle();
      expect(find.text('Could not load facilities.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Retry'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No facilities found.'), findsOneWidget);
    },
  );
}
