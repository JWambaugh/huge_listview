import 'package:flutter/material.dart';

/// Builds something drawn down the side of a list, alongside its scroll thumb.
typedef ScrollRailBuilder = Widget Function(
    BuildContext context, ScrollRailMetrics metrics);

/// Where a list has got to, for anything drawn down the side of it.
///
/// A rail marks places on the same track the thumb travels along, so it works
/// in the track's measurements rather than the viewport's: the thumb has a
/// length of its own, and the ends of the track sit half of it in from the
/// ends of the list.
@immutable
class ScrollRailMetrics {
  /// Length the thumb travels along, in pixels.
  final double trackExtent;

  /// Length of the thumb itself, in pixels.
  final double thumbExtent;

  /// Where the thumb sits on the track, 0 at the start and 1 at the end.
  final double position;

  /// Number of items in the list.
  final int totalCount;

  /// Whether the thumb is being held.
  final bool isDragging;

  /// How far faded in the thumb is, for a rail that comes and goes with it.
  final Animation<double> visibility;

  /// Where on the track the item at [index] sits, 0 to 1.
  final double Function(int index) positionOf;

  const ScrollRailMetrics({
    required this.trackExtent,
    required this.thumbExtent,
    required this.position,
    required this.totalCount,
    required this.isDragging,
    required this.visibility,
    required this.positionOf,
  });

  /// Distance from the leading edge of the list to the point [position] marks.
  ///
  /// Measured to the middle of the thumb, so a mark on the rail and the thumb
  /// that reaches it line up.
  double offsetOf(double position) =>
      position.clamp(0.0, 1.0) * trackExtent + thumbExtent / 2;
}
