import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/features/reader/widgets/single_page_scroll_physics.dart';

void main() {
  const physics = SinglePageScrollPhysics();

  FixedScrollMetrics metrics(double pixels) {
    return FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 4000,
      pixels: pixels,
      viewportDimension: 400,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );
  }

  test('a fast forward fling settles on the next page only', () {
    final simulation = physics.createBallisticSimulation(metrics(880), 100000);

    expect(simulation, isNotNull);
    expect(simulation!.x(100), closeTo(1200, 0.01));
    expect(
      List.generate(
        100,
        (index) => simulation.x(index / 10),
      ).reduce((largest, value) => value > largest ? value : largest),
      lessThanOrEqualTo(1200.01),
    );
  });

  test('a fast backward fling settles on the previous page only', () {
    final simulation = physics.createBallisticSimulation(
      metrics(1120),
      -100000,
    );

    expect(simulation, isNotNull);
    expect(simulation!.x(100), closeTo(800, 0.01));
    expect(
      List.generate(
        100,
        (index) => simulation.x(index / 10),
      ).reduce((smallest, value) => value < smallest ? value : smallest),
      greaterThanOrEqualTo(799.99),
    );
  });
}
