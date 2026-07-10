import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:diario_di_viaggio_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts on Android emulator', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Accedi'), findsOneWidget);
  });
}
