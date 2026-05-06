import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RelayCtrlApp());
    expect(find.text('RelayCtrl Pro'), findsAny);
  });
}
