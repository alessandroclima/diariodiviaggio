import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:diario_di_viaggio_mobile/main.dart';

void main() {
  testWidgets('App boots to auth gate', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SessionStore(ApiClient()),
        child: const DiarioApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(StartupGate), findsOneWidget);
  });
}
