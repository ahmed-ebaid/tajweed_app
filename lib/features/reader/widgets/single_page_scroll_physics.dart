import 'package:flutter/material.dart';

class SinglePageScrollPhysics extends ScrollPhysics {
  const SinglePageScrollPhysics({super.parent});

  @override
  SinglePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SinglePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.viewportDimension <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final currentPage = position.pixels / position.viewportDimension;
    final targetPage = switch (velocity) {
      < 0 when velocity.abs() > tolerance.velocity => currentPage.floor(),
      > 0 when velocity.abs() > tolerance.velocity => currentPage.ceil(),
      _ => currentPage.round(),
    };
    final targetPixels = (targetPage * position.viewportDimension).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((targetPixels - position.pixels).abs() < tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels.toDouble(),
      0,
      tolerance: tolerance,
    );
  }
}
