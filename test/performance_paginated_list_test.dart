import 'package:central_portal_mobile/features/performance/presentation/widgets/performance_paginated_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a bounded page and navigates to remaining items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformancePaginatedList<int>(
            items: List.generate(7, (index) => index),
            itemBuilder:
                (context, item, index) =>
                    Text('Item $item', key: ValueKey(item)),
          ),
        ),
      ),
    );

    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 4'), findsOneWidget);
    expect(find.text('Item 5'), findsNothing);
    expect(find.text('1-5 dari 7 item'), findsOneWidget);

    await tester.tap(find.byTooltip('Halaman berikutnya'));
    await tester.pumpAndSettle();

    expect(find.text('Item 0'), findsNothing);
    expect(find.text('Item 5'), findsOneWidget);
    expect(find.text('Item 6'), findsOneWidget);
    expect(find.text('6-7 dari 7 item'), findsOneWidget);
  });
}
