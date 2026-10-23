import 'package:central_portal_mobile/core/widgets/artech_pull_to_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('short pull dismisses without scheduling a build during layout', (
    tester,
  ) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArtechPullToRefresh(
            threshold: 60,
            onRefresh: () async {
              refreshCount++;
            },
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(height: 1000),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 30));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(refreshCount, 0);
  });
}
