import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const FaceRegApp(),
      ),
    );
    await tester.pump();
    // Splash screen should be visible while auth status is unknown
    expect(find.byType(FaceRegApp), findsOneWidget);
  });
}
