import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:admin_app/main.dart';
import 'package:admin_app/features/auth/auth_provider.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const LegacyAdminApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    // Just verify the app can start without crashing
    expect(find.byType(LegacyAdminApp), findsOneWidget);
  });

  testWidgets('App toast is visible near the top of the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showAppToast(
                      AppToast.snackBar(
                        content: const Text('Toast is visible'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Show toast'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final toastFinder = find.text('Toast is visible');
    expect(toastFinder, findsOneWidget);
    final toastY = tester.getTopLeft(toastFinder).dy;
    expect(toastY, greaterThan(60));
    expect(toastY, lessThan(220));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-toast-card'))).height,
      lessThan(70),
    );
  });
}
