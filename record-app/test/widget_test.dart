import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:record_app/screens/login_screen.dart';
import 'package:record_app/services/storage_service.dart';

void main() {
  testWidgets('home screen renders primary actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Provider(
        create: (_) => StorageService(),
        child: const MaterialApp(home: LoginScreen(isSetup: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('PIN'), findsOneWidget);
  });
}
