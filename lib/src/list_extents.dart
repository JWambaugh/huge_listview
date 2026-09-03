import 'dart:math' show max;

/// A running estimate of how much room each item of a list takes up, measured
/// in viewport lengths.
///
/// A scrollbar thumb placed by item index alone travels at whatever rate the
/// items happen to be tall. A day holding three photos claims as much of the
/// track as a day holding three hundred, so the thumb leaps through the one
/// and crawls through the other, and the last screenful of items has no track
/// left to sit on. Measuring the items that have been on screen and guessing
/// the rest at their average keeps the thumb in proportion to the content.
///
/// None of this is exact, and it is not meant to be. Every item that has not
/// been scrolled past is a guess, and the guesses settle as the list is
/// explored.
class ListExtents {
  /// Re-measurements smaller than this, in viewport lengths, are ignored.
  /// Extents wobble by a fraction of a pixel between frames and rebuilding the
  /// running totals for that is wasted work.
  static const double tolerance = 0.001;

  List<double> _extent = <double>[];
  List<bool> _known = <bool>[];

  /// Extent lying before each item, one entry longer than the list so the last
  /// entry is the total. Rebuilt lazily, at most once between measurements.
  List<double> _before = <double>[0];
  double _knownTotal = 0;
  int _knownCount = 0;
  bool _stale = true;

  int get length => _extent.length;

  /// Total extent of the list, in viewport lengths.
  double get total {
    _refresh();
    return _before.last;
  }

  /// The extent of an item that has not been seen yet.
  double get _guess => _knownCount == 0 ? 0 : _knownTotal / _knownCount;

  /// Forget every measurement and start over on a list of [length] items.
  ///
  /// Measurements are keyed by index, and a list whose length changed has
  /// most likely moved them: a day arriving from an import lands in date
  /// order rather than on the end.
  void reset(int length) {
    final count = max(length, 0);
    _extent = List<double>.filled(count, 0);
    _known = List<bool>.filled(count, false);
    _knownTotal = 0;
    _knownCount = 0;
    _stale = true;
  }

  /// Record that the item at [index] measured [extent] viewport lengths.
  void record(int index, double extent) {
    if (index < 0 || index >= _extent.length || extent < 0) return;
    if (_known[index]) {
      if ((_extent[index] - extent).abs() < tolerance) return;
      _knownTotal -= _extent[index];
    } else {
      _knownCount++;
      _known[index] = true;
    }
    _extent[index] = extent;
    _knownTotal += extent;
    _stale = true;
  }

  /// How far the list has scrolled when the item at [index] sits [into]
  /// viewport lengths above the top of the viewport.
  double offsetOf(int index, double into) {
    _refresh();
    if (_extent.isEmpty) return 0;
    return _before[index.clamp(0, _extent.length - 1)] + into;
  }

  /// The item [offset] falls in, and how far into it it falls.
  ///
  /// The second value is what the item's leading edge has to be lifted above
  /// the viewport by to land on [offset], so it is never negative and never
  /// more than that item's own extent.
  ListExtentPosition at(double offset) {
    _refresh();
    if (_extent.isEmpty) return const ListExtentPosition(0, 0);

    // Rightmost item starting at or before the offset.
    var low = 0;
    var high = _extent.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_before[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return ListExtentPosition(low, max(offset - _before[low], 0));
  }

  void _refresh() {
    if (!_stale) return;
    _stale = false;

    final guess = _guess;
    _before = List<double>.filled(_extent.length + 1, 0);
    var running = 0.0;
    for (var i = 0; i < _extent.length; i++) {
      running += _known[i] ? _extent[i] : guess;
      _before[i + 1] = running;
    }
  }
}

/// A point in a list, as an item and a distance into it in viewport lengths.
class ListExtentPosition {
  final int index;
  final double into;

  const ListExtentPosition(this.index, this.into);
}
