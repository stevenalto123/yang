import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double desktop = 860;
  static const double wide = 1120;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}

/// Centers content cleanly on tablet & desktop screens so cards and forms
/// never stretch awkwardly edge-to-edge on web browsers.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}
