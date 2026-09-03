import 'package:flutter/material.dart';

/// A scroll thumb shaped like a drop lying on its side, carrying the date it
/// is pointing at and coming to a point against the rail beside it.
class TimelineThumb extends StatelessWidget {
  /// What the thumb is pointing at. A thumb with nothing to say shrinks to
  /// its round end rather than showing an empty bubble.
  final String? label;

  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final TextStyle? textStyle;
  final double elevation;

  const TimelineThumb({
    Key? key,
    required this.label,
    this.height = 48,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black87,
    this.textStyle,
    this.elevation = 4,
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
        textDirection: Directionality.of(context),
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          // Room for the round end on the left and the point on the right, so
          // the text sits in the body of the drop rather than in its tip.
          padding: EdgeInsets.only(left: height * 0.4, right: height * 0.6),
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
  final TextDirection textDirection;

  _CalloutPainter({
    required this.color,
    required this.elevation,
    required this.textDirection,
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

  /// A rounded end, a straight body, and a tip: the tip is where the thumb is
  /// actually pointing, so it sits on the middle of the shape's own height.
  Path _drop(Size size) {
    final height = size.height;
    final radius = height / 2;
    final taper = radius * 0.9;
    final width = size.width < radius + taper ? radius + taper : size.width;
    final body = width - taper;

    return Path()
      ..moveTo(width, radius)
      ..quadraticBezierTo(body + taper * 0.45, height * 0.08, body, 0)
      ..lineTo(radius, 0)
      ..arcToPoint(Offset(radius, height),
          radius: Radius.circular(radius), clockwise: false)
      ..lineTo(body, height)
      ..quadraticBezierTo(body + taper * 0.45, height * 0.92, width, radius)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _CalloutPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.elevation != elevation;
}
