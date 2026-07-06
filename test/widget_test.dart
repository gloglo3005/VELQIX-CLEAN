import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:VELQIX/main.dart';

void main() {
  testWidgets('VelQix app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VelQixApp(alreadyLoggedIn: false));
    expect(find.text('Louez ou vendez'), findsWidgets);
  });
}