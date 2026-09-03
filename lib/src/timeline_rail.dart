import 'package:flutter/material.dart';
import 'package:huge_listview/src/scroll_rail.dart';

/// The date of the item at [index], or null if it stands for no date.
typedef TimelineDateAt = DateTime? Function(int index);

/// How coarsely a timeline is marked.
enum TimelineScale { years, months }

/// A date scale drawn down the side of a list whose items run in date order.
///
/// Marks are placed where those dates actually sit on the scroll track, not
/// where they would fall on a calendar. A month holding ten thousand photos
/// takes up more of the track than a month holding four, and the rail says so:
/// a mark and the thumb that reaches it point at the same photos.
class TimelineRail extends StatefulWidget {
  final ScrollRailMetrics metrics;

  /// The date the item at an index belongs to.
  final TimelineDateAt dateAt;

  /// Whether the rail stays on screen, rather than coming and going with the
  /// thumb.
  final bool alwaysVisible;

  final double width;
  final Color color;
  final TextStyle? textStyle;

  /// Written against a mark that starts a year.
  final String Function(DateTime date) yearLabel;

  /// Written against a mark that starts a month.
  final String Function(DateTime date) monthLabel;

  const TimelineRail({
    Key? key,
    required this.metrics,
    required this.dateAt,
    this.alwaysVisible = false,
    this.width = 54,
    this.color = Colors.grey,
    this.textStyle,
    this.yearLabel = defaultYearLabel,
    this.monthLabel = defaultMonthLabel,
  }) : super(key: key);

  static const _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _fullMonths = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String defaultYearLabel(DateTime date) => '${date.year}';

  /// A whole date, for a thumb that has the room to show one.
  static String defaultDayLabel(DateTime date) =>
      '${_fullMonths[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';

  /// A month carries its year when it is the one that starts it, so a run of
  /// months says which year it belongs to without repeating it twelve times.
  static String defaultMonthLabel(DateTime date) => date.month == 1
      ? '${_months[date.month - 1]} ${date.year}'
      : _months[date.month - 1];

  @override
  State<TimelineRail> createState() => _TimelineRailState();
}

class _TimelineRailState extends State<TimelineRail> {
  List<TimelineMark> _marks = const [];
  int _markedCount = -1;
  TimelineScale _scale = TimelineScale.years;

  @override
  void didUpdateWidget(TimelineRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textStyle != oldWidget.textStyle ||
        widget.dateAt != oldWidget.dateAt) _markedCount = -1;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        Theme.of(context).textTheme.labelSmall ??
        const TextStyle(fontSize: 11);
    _markIfStale(style);

    final rail = CustomPaint(
      size: Size(widget.width, double.infinity),
      painter: _TimelineRailPainter(
        marks: _marks,
        metrics: widget.metrics,
        color: widget.color,
        repaint: widget.metrics.visibility,
        opacity: widget.alwaysVisible ? null : widget.metrics.visibility,
      ),
    );
    return SizedBox(width: widget.width, child: rail);
  }

  /// Walking the whole list to find where the years turn over is only worth
  /// doing when the list itself changes. Where those marks land moves with
  /// every scroll, but that is the painter's business.
  void _markIfStale(TextStyle style) {
    final total = widget.metrics.totalCount;
    if (total == _markedCount) return;
    _markedCount = total;

    final found = TimelineMarks.of(totalCount: total, dateAt: widget.dateAt);
    _scale = found.scale;
    _marks = found.marks;

    for (final mark in _marks) {
      mark.label = _scale == TimelineScale.years
          ? widget.yearLabel(mark.date)
          : widget.monthLabel(mark.date);
      mark.painter = TextPainter(
        text: TextSpan(text: mark.label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }
}

/// The date boundaries of a list, and how coarsely they are worth marking.
@immutable
class TimelineMarks {
  final TimelineScale scale;
  final List<TimelineMark> marks;

  const TimelineMarks(this.scale, this.marks);

  /// Find where the list turns over into a new year or a new month, and pick
  /// which of the two to mark it by.
  static TimelineMarks of({
    required int totalCount,
    required TimelineDateAt dateAt,
  }) {
    final years = <TimelineMark>[];
    final months = <TimelineMark>[];
    DateTime? previous;
    for (var index = 0; index < totalCount; index++) {
      final date = dateAt(index);
      if (date == null) continue;
      final newYear = previous == null || date.year != previous.year;
      if (newYear) years.add(TimelineMark(index, date, true));
      if (newYear || date.month != previous.month)
        months.add(TimelineMark(index, date, newYear));
      previous = date;
    }

    // Enough years to read as a scale of their own, or so many months that
    // they would never all fit on the rail anyway.
    final scale = years.length >= 4 || months.length > 24
        ? TimelineScale.years
        : TimelineScale.months;
    return TimelineMarks(scale, scale == TimelineScale.years ? years : months);
  }
}

/// One date boundary in the list, and where it falls.
class TimelineMark {
  final int index;
  final DateTime date;

  /// Whether this starts a year rather than only a month.
  final bool major;

  String label = '';
  TextPainter? painter;

  TimelineMark(this.index, this.date, this.major);
}

class _TimelineRailPainter extends CustomPainter {
  /// Ticks closer together than this are dropped, so a dense stretch of the
  /// list thins out rather than smearing into a solid bar.
  static const double _minTickGap = 6;

  /// Labels need the room to be read, and more of it than a tick does.
  static const double _minLabelGap = 4;

  final List<TimelineMark> marks;
  final ScrollRailMetrics metrics;
  final Color color;
  final Animation<double>? opacity;

  _TimelineRailPainter({
    required this.marks,
    required this.metrics,
    required this.color,
    required this.opacity,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = opacity?.value ?? 1.0;
    if (fade <= 0 || marks.isEmpty) return;

    final tick = Paint()
      ..color = color.withValues(alpha: color.a * fade)
      ..strokeWidth = 1
      ..isAntiAlias = true;

    var lastTick = double.negativeInfinity;
    var lastLabelEnd = double.negativeInfinity;
    for (final mark in marks) {
      final y = metrics.offsetOf(metrics.positionOf(mark.index));
      if (y - lastTick < _minTickGap) continue;
      lastTick = y;

      final painter = mark.painter;
      final labelled = painter != null &&
          y - painter.height / 2 - lastLabelEnd >= _minLabelGap;

      // A tick that carries a label reaches further in, so the two read as one
      // mark rather than as a line with a caption floating beside it.
      final from = labelled ? size.width - 10 : size.width - 6;
      canvas.drawLine(Offset(from, y), Offset(size.width - 2, y), tick);

      if (!labelled) continue;
      final top = y - painter.height / 2;
      painter.paint(canvas, Offset(size.width - 14 - painter.width, top));
      lastLabelEnd = top + painter.height;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineRailPainter oldDelegate) =>
      oldDelegate.marks != marks ||
      oldDelegate.color != color ||
      oldDelegate.metrics != metrics;
}
