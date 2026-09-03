import 'package:flutter_test/flutter_test.dart';
import 'package:huge_listview/src/list_extents.dart';

void main() {
  group('unmeasured lists', () {
    test('an empty list is nowhere', () {
      final extents = ListExtents()..reset(0);
      expect(extents.total, 0);
      expect(extents.at(0).index, 0);
      expect(extents.offsetOf(0, 0), 0);
    });

    test('items nothing is known about are worth nothing', () {
      final extents = ListExtents()..reset(10);
      expect(extents.total, 0);
    });

    test('one measurement stands in for every item', () {
      final extents = ListExtents()..reset(10);
      extents.record(4, 0.5);
      expect(extents.total, closeTo(5.0, 1e-9));
      expect(extents.offsetOf(2, 0), closeTo(1.0, 1e-9));
    });
  });

  group('measured lists', () {
    ListExtents fixture() {
      // Three items of wildly different height, the middle one taller than the
      // viewport, plus a fourth left unmeasured.
      final extents = ListExtents()..reset(4);
      extents.record(0, 0.25);
      extents.record(1, 3.0);
      extents.record(2, 0.75);
      return extents;
    }

    test('the unmeasured item is guessed at the average of the rest', () {
      // (0.25 + 3.0 + 0.75) / 3
      expect(fixture().total, closeTo(0.25 + 3.0 + 0.75 + 4.0 / 3, 1e-9));
    });

    test('offset accumulates what lies before the item', () {
      final extents = fixture();
      expect(extents.offsetOf(0, 0), 0);
      expect(extents.offsetOf(1, 0), closeTo(0.25, 1e-9));
      expect(extents.offsetOf(2, 0), closeTo(3.25, 1e-9));
      expect(extents.offsetOf(2, 0.5), closeTo(3.75, 1e-9));
    });

    test('at() is the inverse of offsetOf()', () {
      final extents = fixture();
      for (final into in [0.0, 0.4, 1.5]) {
        for (var index = 0; index < 3; index++) {
          if (into > 0 && index != 1) continue; // only item 1 is that tall
          final found = extents.at(extents.offsetOf(index, into));
          expect(found.index, index, reason: 'index $index into $into');
          expect(found.into, closeTo(into, 1e-9));
        }
      }
    });

    test('a tall item is crossed gradually, a short one quickly', () {
      final extents = fixture();
      // Half a viewport of scrolling inside the tall item moves far less of
      // the list than half a viewport inside the short one.
      final throughTall =
          extents.offsetOf(1, 0.5) - extents.offsetOf(1, 0.0);
      final acrossShort =
          extents.offsetOf(1, 0.0) - extents.offsetOf(0, 0.0);
      expect(throughTall, closeTo(0.5, 1e-9));
      expect(acrossShort, closeTo(0.25, 1e-9));
    });

    test('an offset past the end lands in the last item', () {
      final extents = fixture();
      expect(extents.at(extents.total + 5).index, 3);
    });

    test('an offset before the start lands in the first item', () {
      final extents = fixture();
      final found = extents.at(-1);
      expect(found.index, 0);
      expect(found.into, 0);
    });

    test('items of no height do not swallow the offset after them', () {
      final extents = ListExtents()..reset(3);
      extents.record(0, 0.0);
      extents.record(1, 0.5);
      extents.record(2, 0.5);
      expect(extents.offsetOf(1, 0), 0);
      // Two items start at 0; the search settles on the later one, which is
      // where the list actually sits.
      expect(extents.at(0).index, 1);
    });
  });

  group('re-measuring', () {
    test('replacing a measurement replaces its contribution', () {
      final extents = ListExtents()..reset(2);
      extents.record(0, 1.0);
      extents.record(1, 1.0);
      expect(extents.total, closeTo(2.0, 1e-9));
      extents.record(0, 3.0);
      expect(extents.total, closeTo(4.0, 1e-9));
    });

    test('a change smaller than the tolerance is ignored', () {
      final extents = ListExtents()..reset(1);
      extents.record(0, 1.0);
      extents.record(0, 1.0 + ListExtents.tolerance / 2);
      expect(extents.total, 1.0);
    });

    test('reset forgets everything', () {
      final extents = ListExtents()..reset(2);
      extents.record(0, 1.0);
      extents.reset(2);
      expect(extents.total, 0);
    });

    test('out of range and negative measurements are refused', () {
      final extents = ListExtents()..reset(2);
      extents.record(5, 1.0);
      extents.record(-1, 1.0);
      extents.record(0, -1.0);
      expect(extents.total, 0);
    });
  });
}
