import 'package:flutter/widgets.dart';

/// Width breakpoint for the desktop layout shell. Anything `>= kDesktopBreakpoint`
/// renders the sidebar + main-content split on web. Below this width the
/// existing 412×896 phone-frame (>= 600) or pass-through (< 600) layouts win.
const double kDesktopBreakpoint = 1024;

/// Returns true when the current viewport is wide enough for the desktop shell.
/// Always combine with `kIsWeb` at the call site — native (Win/macOS/Linux)
/// desktop builds explicitly do not opt into the new layout for this sprint.
bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= kDesktopBreakpoint;
