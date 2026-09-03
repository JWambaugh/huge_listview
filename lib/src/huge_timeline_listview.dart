import 'package:flutter/material.dart';
import 'package:huge_listview/src/huge_listview.dart';
import 'package:huge_listview/src/huge_listview_controller.dart';
import 'package:huge_listview/src/page_result.dart';
import 'package:huge_listview/src/timeline_rail.dart';
import 'package:huge_listview/src/timeline_thumb.dart';
import 'package:quiver/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// A [HugeListView] whose items run in date order, scrolled against a date
/// scale rather than a bare thumb.
///
/// The rail marks where the years or months actually sit on the track, so it
/// reads as a timeline of the content and not of the calendar: a busy month
/// takes up more of it than a quiet year. Tapping or dragging the rail goes
/// there, and the thumb carries the date it is pointing at.
///
/// The plain [HugeListView] is untouched by any of this; a list that is not a
/// timeline keeps its old thumb.
class HugeTimelineListView<T> extends StatelessWidget {
  /// The date the item at an index belongs to. Items with no date of their
  /// own, such as a card pinned to the top of the list, return null and are
  /// left off the scale.
  final TimelineDateAt dateAt;

  /// What the thumb says while it points at an item. Defaults to the rail's
  /// own labelling of that item's date.
  final String? Function(int index)? labelAt;

  /// Whether the rail stays on screen rather than coming and going with the
  /// thumb.
  final bool alwaysVisibleRail;

  /// Whether to draw the rail at all. A list too short to be worth scrubbing
  /// is better off without one.
  final bool showRail;

  /// Whether to draw the thumb at all. A list showing a single day has no
  /// timeline to place itself on.
  final bool showThumb;

  final double railWidth;
  final Color? railColor;
  final TextStyle? railTextStyle;
  final Color? thumbColor;
  final Color? thumbTextColor;
  final TextStyle? thumbTextStyle;

  /// How far the thumb's point reaches out past its body, as a share of its
  /// height.
  final double thumbTaper;

  final ItemScrollController? scrollController;
  final HugeListViewController? listViewController;
  final int pageSize;
  final int startIndex;
  final HugeListViewPageFuture<T> pageFuture;
  final HugeListViewItemBuilder<T> itemBuilder;
  final IndexedWidgetBuilder placeholderBuilder;
  final WidgetBuilder? waitBuilder;
  final WidgetBuilder? emptyBuilder;
  final HugeListViewErrorBuilder? errorBuilder;
  final double velocityThreshold;
  final ValueChanged<int>? firstShown;
  final EdgeInsets? padding;
  final double thumbHeight;
  final Duration thumbAnimationDuration;
  final Duration thumbVisibleDuration;
  final LruMap<int, HugeListViewPageResult<T>>? lruMap;

  const HugeTimelineListView({
    Key? key,
    required this.dateAt,
    required this.pageSize,
    required this.startIndex,
    required this.pageFuture,
    required this.itemBuilder,
    required this.placeholderBuilder,
    this.labelAt,
    this.alwaysVisibleRail = false,
    this.showRail = true,
    this.showThumb = true,
    this.railWidth = 54,
    this.railColor,
    this.railTextStyle,
    this.thumbColor,
    this.thumbTextColor,
    this.thumbTextStyle,
    this.thumbTaper = 0.8,
    this.scrollController,
    this.listViewController,
    this.waitBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.velocityThreshold = 128,
    this.firstShown,
    this.padding,
    this.thumbHeight = 32,
    this.thumbAnimationDuration = kThemeAnimationDuration,
    this.thumbVisibleDuration = const Duration(milliseconds: 1000),
    this.lruMap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rail = railColor ?? scheme.onSurface.withValues(alpha: 0.55);

    return HugeListView<T>(
      scrollController: scrollController,
      listViewController: listViewController,
      pageSize: pageSize,
      startIndex: startIndex,
      pageFuture: pageFuture,
      itemBuilder: itemBuilder,
      placeholderBuilder: placeholderBuilder,
      waitBuilder: waitBuilder,
      emptyBuilder: emptyBuilder,
      errorBuilder: errorBuilder,
      velocityThreshold: velocityThreshold,
      firstShown: firstShown,
      padding: padding,
      lruMap: lruMap,
      alwaysVisibleThumb: false,
      thumbHeight: thumbHeight,
      thumbAnimationDuration: thumbAnimationDuration,
      thumbVisibleDuration: thumbVisibleDuration,
      // The thumb points at the rail, so it has to stand clear of it.
      thumbPadding: showRail ? EdgeInsets.only(right: railWidth) : null,
      railBuilder: !showRail
          ? null
          : (context, metrics) => TimelineRail(
                metrics: metrics,
                dateAt: dateAt,
                alwaysVisible: alwaysVisibleRail,
                width: railWidth,
                color: rail,
                textStyle: railTextStyle,
              ),
      thumbBuilder:
          (background, draw, height, index, alwaysVisible, animation) {
        if (!showThumb) return const SizedBox.shrink();
        final thumb = TimelineThumb(
          label: _label(index),
          height: height,
          // The thumb has to read against the photos behind it, which are
          // whatever colour they happen to be. `inverseSurface` is the role
          // that is deliberately far from the background in either theme,
          // rather than a surface tint that all but disappears in one of them.
          backgroundColor: thumbColor ?? scheme.inverseSurface,
          foregroundColor: thumbTextColor ?? scheme.onInverseSurface,
          textStyle: thumbTextStyle,
          taper: thumbTaper,
        );
        return alwaysVisible
            ? thumb
            : FadeTransition(opacity: animation, child: thumb);
      },
    );
  }

  String? _label(int index) {
    final custom = labelAt;
    if (custom != null) return custom(index);
    final date = dateAt(index);
    return date == null ? null : TimelineRail.defaultDayLabel(date);
  }
}
