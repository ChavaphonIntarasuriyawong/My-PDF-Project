import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intercepts the Escape key anywhere in [child]'s subtree and calls
/// [onEscape]. Works on all platforms (desktop, web, keyboard-attached mobile).
/// Does not affect the Android back gesture or iOS swipe — those are handled
/// by PopScope / GoRouter's own pop logic.
class EscapePopScope extends StatelessWidget {
  final Widget child;
  final VoidCallback onEscape;

  const EscapePopScope({
    super.key,
    required this.child,
    required this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        onEscape();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
