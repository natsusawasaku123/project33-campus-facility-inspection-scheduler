import 'package:campus_facility_inspection_scheduler/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Displays the facility returned by the API', (tester) async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url, Uri.parse('$apiBaseUrl/facilities'));

      return http.Response('[{"id":1,"name":"Demo Science Room"}]', 200);
    });
    addTearDown(client.close);

    await tester.pumpWidget(InspectionApp(client: client));
    await tester.pumpAndSettle();

    expect(find.text('Demo Science Room'), findsOneWidget);
    expect(find.text('Facility ID: 1'), findsOneWidget);
  });
}