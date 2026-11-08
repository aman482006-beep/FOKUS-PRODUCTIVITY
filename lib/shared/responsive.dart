import 'package:flutter/material.dart';

/// Responsive layout breakpoint utilities.
///
/// Use these constants and helper widgets to build adaptive layouts
/// that look great on mobile, tablet, and desktop.
const double mobileBreakpoint = 600.0;
const double tabletBreakpoint = 960.0;
const double desktopBreakpoint = 1200.0;

/// Returns true if the current screen width is below [mobileBreakpoint].
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < mobileBreakpoint;

/// Returns true if the current screen width is between mobile and tablet.
bool isTablet(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= mobileBreakpoint && width < tabletBreakpoint;
}

/// Returns true if the current screen width is at or above [tabletBreakpoint].
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= tabletBreakpoint;

/// A widget that builds different layouts based on available width.
///
/// Uses [LayoutBuilder] to determine the current constraint width
/// and switches between mobile, tablet, and desktop layouts.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) builder;

  const ResponsiveLayout({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

/// Returns the responsive padding for page content.
EdgeInsets responsivePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < mobileBreakpoint) {
    return const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 16);
  } else if (width < tabletBreakpoint) {
    return const EdgeInsets.only(left: 24, right: 24, top: 28, bottom: 20);
  }
  return const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24);
}

/// Returns the responsive font size multiplier.
double responsiveFontSize(BuildContext context, {double base = 24.0}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < mobileBreakpoint) {
    return (base * 0.75).clamp(16.0, base);
  }
  return base;
}
