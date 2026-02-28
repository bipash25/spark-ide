import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/app.dart';

void main() {
  testWidgets('Spark IDE launches with welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SparkApp()),
    );
    await tester.pumpAndSettle();

    // Verify the app launches and shows Spark IDE branding
    expect(find.text('Spark IDE'), findsWidgets);
  });
}
