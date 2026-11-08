import 'package:flutter/widgets.dart';

/// Requests the next page when the wrapped vertical scrollable gets within
/// [threshold] pixels of its end.
class LoadMoreListener extends StatelessWidget {
  final bool canLoadMore;
  final VoidCallback onLoadMore;
  final Widget child;
  final double threshold;

  const LoadMoreListener({
    super.key,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.child,
    this.threshold = 200,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (canLoadMore &&
            metrics.axis == Axis.vertical &&
            metrics.extentAfter <= threshold) {
          onLoadMore();
        }
        return false;
      },
      child: child,
    );
  }
}
