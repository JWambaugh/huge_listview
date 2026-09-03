import 'dart:async';
import 'dart:math' show max, min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huge_listview/src/draggable_scrollbar_thumbs.dart';

class DraggableScrollbar extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;
  final Color drawColor;
  final double heightScrollThumb;
  final EdgeInsetsGeometry? padding;
  final bool alwaysVisibleThumb;
  final Duration thumbAnimationDuration;
  final Duration thumbVisibleDuration;
  final int totalCount;
  final int initialScrollIndex;
  final int currentFirstIndex;
  final ValueChanged<double>? onChange;

  /// Which item the thumb points at from where it sits along the track.
  ///
  /// Only used for the label, and to spot the list refusing to go where it
  /// was sent. Defaults to spreading the items evenly over the track, which
  /// is right only if they are all the same size.
  final int Function(double position)? indexAt;
  final ScrollThumbBuilder scrollThumbBuilder;
  final Axis scrollDirection;

  const DraggableScrollbar({
    Key? key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.drawColor = Colors.grey,
    this.heightScrollThumb = 48.0,
    this.padding,
    this.alwaysVisibleThumb = true,
    this.thumbAnimationDuration = kThemeAnimationDuration,
    this.thumbVisibleDuration = const Duration(milliseconds: 1000),
    this.totalCount = 1,
    this.initialScrollIndex = 0,
    this.currentFirstIndex = 0,
    required this.scrollThumbBuilder,
    this.onChange,
    this.indexAt,
    this.scrollDirection = Axis.vertical,
  }) : super(key: key);

  @override
  DraggableScrollbarState createState() => DraggableScrollbarState();
}

class DraggableScrollbarState extends State<DraggableScrollbar>
    with TickerProviderStateMixin {
  double thumbOffset = 0.0;
  int currentFirstIndex = 0;
  bool isDragging = false;
  late AnimationController thumbAnimationController;
  late Animation<double> thumbAnimation;
  Timer? fadeoutTimer;

  /// The index the thumb last asked the list to jump to, while dragging.
  ///
  /// Only used to spot the list reporting back short of it, and to avoid
  /// asking for the same index twice in a row.
  int? requestedIndex;

  /// How far down the track the thumb may go for the rest of this drag.
  ///
  /// The last items of a list can never be scrolled to the top -- the list
  /// runs out of content first -- so the bottom of the track maps onto
  /// positions the list will refuse. `null` until a refusal shows where that
  /// starts.
  double? dragOffsetLimit;

  double get thumbMin => 0.0;

  double get thumbMax => widget.scrollDirection == Axis.vertical //
      ? context.size!.height - widget.heightScrollThumb
      : context.size!.width - widget.heightScrollThumb;

  @override
  void initState() {
    super.initState();

    thumbAnimationController = AnimationController(
      vsync: this,
      duration: widget.thumbAnimationDuration,
    );

    thumbAnimation = CurvedAnimation(
      parent: thumbAnimationController,
      curve: Curves.fastOutSlowIn,
    );

    currentFirstIndex = widget.currentFirstIndex;
    if (widget.initialScrollIndex > 0 && widget.totalCount > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => thumbOffset =
            (widget.initialScrollIndex / widget.totalCount) *
                (thumbMax - thumbMin));
      });
    }
  }

  @override
  void didUpdateWidget(DraggableScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.totalCount != widget.totalCount) {
      // A different number of items is a different end of the list, so
      // anything learnt about where it stops no longer holds.
      requestedIndex = null;
      dragOffsetLimit = null;
    }
  }

  /// The item the thumb points at when it sits [position] down the track.
  int indexFor(double position) {
    if (widget.totalCount <= 0) return 0;
    final resolve = widget.indexAt;
    final index = resolve != null
        ? resolve(position)
        : (position * widget.totalCount).floor();
    return index.clamp(0, widget.totalCount - 1);
  }

  @override
  void dispose() {
    thumbAnimationController.dispose();
    fadeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!isDragging &&
              (notification is ScrollUpdateNotification ||
                  notification is OverscrollNotification)) {
            if (thumbAnimationController.status != AnimationStatus.forward)
              thumbAnimationController.forward();
            fadeoutTimer?.cancel();
            fadeoutTimer = Timer(widget.thumbVisibleDuration, () {
              thumbAnimationController.reverse();
              fadeoutTimer = null;
            });
          }
          return false;
        },
        child: Stack(
          children: [
            RepaintBoundary(child: widget.child),
            RepaintBoundary(child: buildDetector()),
          ],
        ),
      );

  Widget buildKeyboard() {
    if (defaultTargetPlatform == TargetPlatform.windows)
      return RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: keyHandler,
        child: buildDetector(),
      );
    else
      return buildDetector();
  }

  Widget buildDetector() => GestureDetector(
        onVerticalDragStart: onDragStart,
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: onDragEnd,
        onHorizontalDragStart: onDragStart,
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: onDragEnd,
        child: Container(
          alignment: widget.scrollDirection == Axis.vertical //
              ? Alignment.topRight
              : Alignment.bottomLeft,
          margin: widget.scrollDirection == Axis.vertical //
              ? EdgeInsets.only(top: thumbOffset)
              : EdgeInsets.only(left: thumbOffset),
          padding: widget.padding,
          child: widget.scrollThumbBuilder.call(
            widget.backgroundColor,
            widget.drawColor,
            widget.heightScrollThumb,
            currentFirstIndex,
            widget.alwaysVisibleThumb,
            thumbAnimation,
          ),
        ),
      );

  void setPosition(double position, int currentFirstIndex) {
    if (isDragging) {
      // The list reports back on every scroll frame, the ones caused by the
      // drag itself included. Following it here would snap the thumb to
      // `index / totalCount` while the finger still holds it: invisible over
      // thousands of items, a jump per frame over a dozen.
      //
      // The report is still worth one thing. Asking for an index the list
      // cannot put at the top leaves it short, which is how we find out that
      // the rest of the track leads nowhere.
      if (requestedIndex != null && currentFirstIndex < requestedIndex!) {
        setState(() {
          this.currentFirstIndex = currentFirstIndex;
          requestedIndex = currentFirstIndex;
          dragOffsetLimit = position * (thumbMax - thumbMin);
          thumbOffset = min(thumbOffset, dragOffsetLimit!);
        });
      }
      return;
    }
    setState(() {
      this.currentFirstIndex = currentFirstIndex;
      thumbOffset = position * (thumbMax - thumbMin);
    });
  }

  void onDragStart(DragStartDetails details) {
    setState(() {
      isDragging = true;
      requestedIndex = null;
      dragOffsetLimit = null;
      fadeoutTimer?.cancel();
    });
  }

  void onDragUpdate(DragUpdateDetails details) {
    if (!isDragging) return;

    final delta = widget.scrollDirection == Axis.vertical
        ? details.delta.dy
        : details.delta.dx;
    if (delta == 0) return;

    if (thumbAnimationController.status != AnimationStatus.forward)
      thumbAnimationController.forward();

    final track = thumbMax - thumbMin;
    if (track <= 0) return;

    final offset = (thumbOffset + delta)
        .clamp(thumbMin, max(thumbMin, dragOffsetLimit ?? thumbMax))
        .toDouble();
    final position = offset / track;
    final index = indexFor(position);

    setState(() {
      thumbOffset = offset;
      // The thumb leads and the list follows, so the label has to come from
      // where the thumb is rather than from where the list has got to.
      currentFirstIndex = index;
    });

    // The list is sent to the exact position rather than to the nearest item,
    // so every move of the thumb is worth passing on.
    requestedIndex = index;
    widget.onChange?.call(position);
  }

  void onDragEnd(DragEndDetails details) {
    fadeoutTimer = Timer(widget.thumbVisibleDuration, () {
      thumbAnimationController.reverse();
      fadeoutTimer = null;
    });
    setState(() {
      isDragging = false;
      requestedIndex = null;
      dragOffsetLimit = null;
    });
  }

  void keyHandler(RawKeyEvent value) {
    if (value.runtimeType == RawKeyDownEvent) {
      if (widget.scrollDirection == Axis.vertical &&
          value.logicalKey == LogicalKeyboardKey.arrowDown)
        onDragUpdate(DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(0, 2),
        ));
      else if (widget.scrollDirection == Axis.vertical &&
          value.logicalKey == LogicalKeyboardKey.arrowUp)
        onDragUpdate(DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(0, -2),
        ));
      else if (widget.scrollDirection == Axis.horizontal &&
          value.logicalKey == LogicalKeyboardKey.arrowRight)
        onDragUpdate(DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(2, 0),
        ));
      else if (widget.scrollDirection == Axis.horizontal &&
          value.logicalKey == LogicalKeyboardKey.arrowLeft)
        onDragUpdate(DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(-2, 0),
        ));
      else if (value.logicalKey == LogicalKeyboardKey.pageDown)
        onDragUpdate(DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: widget.scrollDirection == Axis.horizontal
              ? const Offset(25, 0)
              : const Offset(0, 25),
        ));
      else if (value.logicalKey == LogicalKeyboardKey.pageUp)
        onDragUpdate(DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: widget.scrollDirection == Axis.horizontal
              ? const Offset(-25, 0)
              : const Offset(0, -25),
        ));
    }
  }
}
