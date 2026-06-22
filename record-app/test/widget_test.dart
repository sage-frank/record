import 'package:flutter_test/flutter_test.dart';

import 'package:record_app/main.dart';

void main() {
  testWidgets('home screen renders primary actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RecordApp());

    expect(find.text('运动记录'), findsOneWidget);
    expect(find.text('开始跑步'), findsOneWidget);
    expect(find.text('历史记录'), findsOneWidget);
  });
}
