import 'package:flutter_test/flutter_test.dart';
import 'package:huge_listview/src/timeline_rail.dart';

/// A list running newest first, [step] calendar days apart from [start].
///
/// Counted in calendar days rather than by subtracting a [Duration]: an exact
/// 24 hours a day walks an hour off course across a daylight saving boundary,
/// which is enough to move an item into the month before.
TimelineDateAt descending(DateTime start, [int step = 1]) => (index) =>
    DateTime(start.year, start.month, start.day - step * index);

void main() {
  group('picking a scale', () {
    test('a library spanning years is marked by year', () {
      // Ten years of days, one item a month so the walk stays cheap.
      final marks = TimelineMarks.of(
        totalCount: 120,
        dateAt: descending(DateTime(2026, 1, 1), 31),
      );
      expect(marks.scale, TimelineScale.years);
      expect(marks.marks.length, greaterThanOrEqualTo(10));
      expect(marks.marks.first.date.year, 2026);
    });

    test('a few months are marked by month', () {
      final marks = TimelineMarks.of(
        totalCount: 90,
        dateAt: descending(DateTime(2023, 4, 1)),
      );
      expect(marks.scale, TimelineScale.months);
      // April, March, February and January.
      expect(marks.marks.length, 4);
      expect(marks.marks.map((mark) => mark.date.month), [4, 3, 2, 1]);
    });

    test('four years is enough to switch to years', () {
      final marks = TimelineMarks.of(
        totalCount: 4,
        dateAt: (index) => DateTime(2026 - index, 6, 1),
      );
      expect(marks.scale, TimelineScale.years);
      expect(marks.marks.length, 4);
    });

    test('three years is still marked by month', () {
      final marks = TimelineMarks.of(
        totalCount: 3,
        dateAt: (index) => DateTime(2026 - index, 6, 1),
      );
      expect(marks.scale, TimelineScale.months);
    });

    test('more months than fit fall back to years', () {
      // 30 months inside three calendar years: too many to label, and only
      // three year marks, so the month count is what decides it.
      final marks = TimelineMarks.of(
        totalCount: 30,
        dateAt: descending(DateTime(2026, 6, 1), 31),
      );
      expect(marks.scale, TimelineScale.years);
    });
  });

  group('what gets marked', () {
    test('a mark points at the first item of its period', () {
      final marks = TimelineMarks.of(
        totalCount: 60,
        dateAt: descending(DateTime(2023, 3, 30)),
      );
      // March 30 back to March 1 is thirty items, so February starts at 30.
      expect(marks.marks[1].index, 30);
      expect(marks.marks[1].date.month, 2);
    });

    test('items with no date of their own are left off the scale', () {
      final marks = TimelineMarks.of(
        totalCount: 5,
        dateAt: (index) => index == 0 ? null : DateTime(2026 - index, 6, 1),
      );
      expect(marks.marks.map((mark) => mark.index), [1, 2, 3, 4]);
    });

    test('a year mark is major, a month inside it is not', () {
      final marks = TimelineMarks.of(
        totalCount: 90,
        dateAt: descending(DateTime(2023, 3, 1), 30),
      );
      expect(marks.scale, TimelineScale.years);
      expect(marks.marks.every((mark) => mark.major), isTrue);
    });

    test('an empty list has nothing to mark', () {
      final marks = TimelineMarks.of(totalCount: 0, dateAt: (_) => null);
      expect(marks.marks, isEmpty);
    });

    test('a list of one is marked by month', () {
      final marks =
          TimelineMarks.of(totalCount: 1, dateAt: (_) => DateTime(2024, 7, 4));
      expect(marks.scale, TimelineScale.months);
      expect(marks.marks.single.index, 0);
    });
  });

  group('labels', () {
    test('a year reads as its number', () {
      expect(TimelineRail.defaultYearLabel(DateTime(2023, 5)), '2023');
    });

    test('a month carries two digits of its year only when it starts one', () {
      expect(TimelineRail.defaultMonthLabel(DateTime(2023, 5)), 'May');
      expect(TimelineRail.defaultMonthLabel(DateTime(2023, 1)), "Jan '23");
    });

    test('a day reads in full, for the thumb', () {
      expect(TimelineRail.defaultDayLabel(DateTime(2023, 2, 5)),
          'February 05, 2023');
    });
  });
}
