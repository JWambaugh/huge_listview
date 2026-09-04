import 'package:flutter/material.dart';

/// The thumb's silhouette: a round end, a straight body, and a point.
///
/// Public because the shape is the reason a thumb reads as *pointing at* the
/// rail beside it, and a caller supplying its own thumb through
/// [HugeTimelineListView.thumbBuilder] should be able to clip or stroke the
/// same outline rather than reproducing this arithmetic.
///
/// The point sits on the middle of the shape's own height. Each side of it is
/// a cubic with its two ends doing different jobs: it leaves the tip almost
/// level, which is what makes the point sharp rather than a blunt wedge, and
/// it arrives at the body dead level, so the silhouette swells out of the
/// round end and holds its full height a while before falling away. A single
/// curve can only do one or the other, and doing just the first pinches the
/// shape into a wedge.
Path timelineThumbPath(Size size, {double taper = TimelineThumb.defaultTaper}) {
  final height = size.height;
  final radius = height / 2;
  final reach = height * taper;
  final width = size.width;
  // Never behind the round end, so a box too narrow for the point loses some
  // of its length rather than growing one out of its own bounds.
  final body = width - reach < radius ? radius : width - reach;

  /// Sets the angle the sides meet at: the nearer the tip's own centre line,
  /// the sharper the point.
  final tipX = width - reach * 0.28;
  const tipY = 0.44;

  /// Level with the body, and far enough back along the point that the curve
  /// stays out there rather than turning down at once.
  final swellX = width - reach * 0.8;

  return Path()
    ..moveTo(width, radius)
    ..cubicTo(tipX, height * tipY, swellX, 0, body, 0)
    ..lineTo(radius, 0)
    ..arcToPoint(Offset(radius, height),
        radius: Radius.circular(radius), clockwise: false)
    ..lineTo(body, height)
    ..cubicTo(swellX, height, tipX, height * (1 - tipY), width, radius)
    ..close();
}

/// Clips a child to [timelineThumbPath], for a thumb that has to shape
/// something other than a flat fill - a frosted pane, a gradient, an image.
class TimelineThumbClipper extends CustomClipper<Path> {
  const TimelineThumbClipper({this.taper = TimelineThumb.defaultTaper});

  final double taper;

  @override
  Path getClip(Size size) => timelineThumbPath(size, taper: taper);

  @override
  bool shouldReclip(TimelineThumbClipper oldClipper) =>
      oldClipper.taper != taper;
}

/// A scroll thumb shaped like a drop lying on its side, carrying the date it
/// is pointing at and coming to a point against the rail beside it.
class TimelineThumb extends StatelessWidget {
  /// How far the tip reaches out past the body, as a share of the height.
  static const double defaultTaper = 1.2;

  /// The narrowest a thumb of [height] can be and still hold its whole point.
  ///
  /// The shape is drawn to fill its box, so a box shorter than this does not
  /// grow a point out of its own bounds - it loses the end of one.
  static double minWidthFor(double height,
          {double taper = defaultTaper}) =>
      height / 2 + height * taper;

  /// Where a label can sit inside a thumb of [height] without running into
  /// either end.
  ///
  /// The round end is generous enough that text can sit well into it, so the
  /// left side needs little. The right has to clear the point, which is where
  /// the shape runs out of height.
  static EdgeInsets labelPadding(double height,
          {double taper = defaultTaper}) =>
      EdgeInsets.only(left: height * 0.22, right: height * taper * 0.72);

  /// What the thumb is pointing at. A thumb with nothing to say shrinks to
  /// its round end rather than showing an empty bubble.
  final String? label;

  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final TextStyle? textStyle;
  final double elevation;

  /// How far the tip reaches out past the body, as a share of the height.
  ///
  /// A longer reach is a narrower point: the sides have further to travel to
  /// meet, so they meet at a shallower angle.
  final double taper;

  const TimelineThumb({
    Key? key,
    required this.label,
    this.height = 32,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black87,
    this.textStyle,
    this.elevation = 4,
    this.taper = defaultTaper,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = label;
    final style = (textStyle ??
            Theme.of(context).textTheme.labelLarge ??
            const TextStyle(fontSize: 14))
        .copyWith(color: foregroundColor);

    return CustomPaint(
      painter: _CalloutPainter(
        color: backgroundColor,
        elevation: elevation,
        taper: taper,
      ),
      child: ConstrainedBox(
        // The point needs its length whether or not there is a date to carry,
        // and the shape is drawn to fill this box. Left to shrink to its
        // content, the box came out shorter than the point and the tip was
        // painted out past the right of it.
        constraints: BoxConstraints(
          minWidth: minWidthFor(height, taper: taper),
          minHeight: height,
          maxHeight: height,
        ),
        child: Padding(
          padding: labelPadding(height, taper: taper),
          child: Center(
            widthFactor: 1,
            child: text == null
                ? const SizedBox.shrink()
                : Text(text, style: style, maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}

class _CalloutPainter extends CustomPainter {
  final Color color;
  final double elevation;
  final double taper;

  _CalloutPainter({
    required this.color,
    required this.elevation,
    required this.taper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _drop(size);
    if (elevation > 0)
      canvas.drawShadow(path, Colors.black, elevation, color.a < 1);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true);
  }

  Path _drop(Size size) => timelineThumbPath(size, taper: taper);

  @override
  bool shouldRepaint(covariant _CalloutPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.elevation != elevation ||
      oldDelegate.taper != taper;
}
