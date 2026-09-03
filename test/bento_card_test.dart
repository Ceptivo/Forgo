import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forgo/core/widgets/bento_grid.dart';

void main() {
  testWidgets(
    'BentoCard used standalone in an unbounded-height Column does not throw',
    (tester) async {
      // Regression test: BentoCard previously forced `height: double.infinity`,
      // which is harmless inside a BentoGrid cell (tight constraints) but
      // throws "RenderBox was given an infinite size" when the card is used
      // standalone in a plain Column (e.g. the wallet balance card), whose
      // main axis is unbounded.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  BentoCard(child: Text('hello')),
                  BentoCard(child: Text('world')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
