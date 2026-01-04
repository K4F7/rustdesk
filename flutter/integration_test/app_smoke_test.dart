import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_hbb/main.dart' as app;
import 'package:flutter_hbb/mobile/pages/home_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to home', (tester) async {
    await app.main(<String>[]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HomePage), findsOneWidget);
  });
}
