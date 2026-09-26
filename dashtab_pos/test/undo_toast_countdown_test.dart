import 'package:dashtab_pos/core/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper: pump a bare app, show the toast, and return the subtitle text.
  Future<String> subtitleAfter(
    WidgetTester tester, {
    String subtitle = 'Deleting in 5s',
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onAction,
  }) async {
    BuildContext? toastContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              toastContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    showToast(
      toastContext!,
      'Item deleted',
      subtitle: subtitle,
      icon: null,
      kind: 'danger',
      actionLabel: 'Undo',
      onAction: onAction,
      duration: duration,
    );
    await tester.pump(); // build the overlay entry
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    // The subtitle is the text that starts with the prefix of the subtitle.
    return texts.firstWhere((t) => t.endsWith('s') && t != 'Item deleted',
        orElse: () => '');
  }

  testWidgets('undo toast counts down 4…3…2…1 live', (tester) async {
    await subtitleAfter(tester);
    expect(find.text('Deleting in 5s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Deleting in 4s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Deleting in 3s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Deleting in 2s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Deleting in 1s'), findsOneWidget);

    // Flush the remaining window so no toast timers leak out of the test.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Item deleted'), findsNothing);
  });

  testWidgets('undo toast disappears after the full window', (tester) async {
    await subtitleAfter(tester);
    expect(find.text('Deleting in 5s'), findsOneWidget);

    // 4 ticks to "1s", then the toast auto-dismisses at 5s.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Deleting in 1s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(); // ticker is canceled now, safe to settle
    expect(find.text('Deleting in 1s'), findsNothing);
    expect(find.text('Item deleted'), findsNothing);
  });

  testWidgets('undo action dismisses the toast immediately', (tester) async {
    var undone = false;
    await subtitleAfter(tester, onAction: () => undone = true);
    expect(find.text('Deleting in 5s'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.text('Deleting in 5s'), findsNothing);
    expect(find.text('Item deleted'), findsNothing);
    // dismiss() cancels both the ticker and the auto-dismiss timer, so no
    // timers are pending here.
  });

  testWidgets('plain subtitle without seconds stays static', (tester) async {
    await subtitleAfter(tester, subtitle: 'Saved to database');
    expect(find.text('Saved to database'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved to database'), findsOneWidget);
    // Flush the rest of the toast lifetime so no timers are left pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Saved to database'), findsNothing);
  });
}
