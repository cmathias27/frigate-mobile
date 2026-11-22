import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/main.dart';

void main() {
  testWidgets('the four tabs are shown and can be switched', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const FrigateMobileApp());
    await tester.pumpAndSettle();

    for (final label in ['Direct', 'Chronologie', 'Alertes', 'Plus']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Chronologie'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sans limite de jours'), findsOneWidget);
  });

  testWidgets('English is used on an English phone', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const FrigateMobileApp());
    await tester.pumpAndSettle();
    expect(find.text('Timeline'), findsOneWidget);
  });
}
