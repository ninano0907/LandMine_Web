import 'dart:math' as math;

/// Rows in the eight-direction walking and mining sheets, clockwise in screen coordinates.
int directionRow(double radians) => (radians / (math.pi / 4)).round() % 8;
