import 'package:flutter/material.dart';

/// Dismisses the current route when the user overscrolls downward.
class SheetDismissOnOverscroll extends StatefulWidget {
  final Widget child;
  final double dismissThreshold;

  const SheetDismissOnOverscroll({
    super.key,
    required this.child,
    this.dismissThreshold = 80,
  });

  @override
  State<SheetDismissOnOverscroll> createState() =>
      _SheetDismissOnOverscrollState();
}

class _SheetDismissOnOverscrollState extends State<SheetDismissOnOverscroll> {
  double _dragDistance = 0;
  double _handleDragDistance = 0;

  bool _handleNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        _dragDistance += -notification.overscroll;
        if (_dragDistance >= widget.dismissThreshold) {
          _dragDistance = 0;
          Navigator.of(context).maybePop();
        }
      } else {
        _dragDistance = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _dragDistance = 0;
    }
    return false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    if (details.primaryDelta! > 0) {
      _handleDragDistance += details.primaryDelta!;
    } else {
      _handleDragDistance = 0;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_handleDragDistance >= widget.dismissThreshold) {
      _handleDragDistance = 0;
      Navigator.of(context).maybePop();
      return;
    }
    _handleDragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 28,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
            ),
          ),
        ],
      ),
    );
  }
}
