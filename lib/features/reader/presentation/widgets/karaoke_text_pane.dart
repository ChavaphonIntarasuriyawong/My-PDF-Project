import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/karaoke_controller.dart';

/// Pre-tokenized span of [KaraokeState.fullText]. Each entry covers a
/// contiguous run of non-whitespace characters; the gap between consecutive
/// tokens is whitespace that we render verbatim (not highlighted).
class _Token {
  final int start;
  final int end;
  final String text;
  const _Token(this.start, this.end, this.text);
}

/// "Karaoke" caption pane that renders the page's TTS text and highlights the
/// word currently being spoken. Auto-scrolls to keep the active span in view.
///
/// Mounted as an `AnimatedPositioned` slide-up sheet from `ReadingScreen`.
/// Designed to live inside a `Stack` taking the bottom ~40% of the reader.
///
/// [onWordTap] receives the char offset (within `KaraokeState.fullText`) of
/// the tapped word's leading character. The reader screen wires this to its
/// `_seekTtsTo(wordStart)` to scrub TTS to that word — null disables tap.
///
/// [currentSpeed] / [onSpeedChange]: optional speed slider in the header.
/// When both are non-null, a 120dp slider lets the user tweak speech rate
/// live. The slider value range is 0.5–2.0x; the reader screen is in charge
/// of mapping that to its native engine clamp.
class KaraokeTextPane extends ConsumerStatefulWidget {
  final void Function(int wordStart)? onWordTap;
  final double? currentSpeed;
  final ValueChanged<double>? onSpeedChange;
  const KaraokeTextPane({
    super.key,
    this.onWordTap,
    this.currentSpeed,
    this.onSpeedChange,
  });

  @override
  ConsumerState<KaraokeTextPane> createState() => _KaraokeTextPaneState();
}

class _KaraokeTextPaneState extends ConsumerState<KaraokeTextPane> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activeKey = GlobalKey();

  // Memoize tokenization keyed off fullText identity — re-tokenizing on every
  // progress tick is wasted work on long pages (book chapters can run 5k+ chars).
  String? _cachedFullText;
  List<_Token> _cachedTokens = const [];

  // Music-app pattern (Spotify / Apple Music lyrics): the user can drag the
  // caption out from under the active word without getting yanked back. While
  // [_userFollowing] is true, every progress tick re-centers the highlight.
  // A user-initiated scroll flips it to false and surfaces the "jump back"
  // pill; only an explicit pill tap re-engages follow.
  //
  // Local UI state by design — purely ephemeral, scoped to this widget's
  // lifetime. No business logic depends on it, so Riverpod would be overkill
  // (CLAUDE.md exception for ephemeral UI state).
  bool _userFollowing = true;

  // Edge-detection for "TTS stopped" and "pane just opened" transitions.
  // We compare current vs. last-seen state in build() and reset follow on
  // either edge so the next playback session starts clean — matches the
  // spec: only an explicit user scroll suspends auto-follow.
  bool _lastIsSpeaking = false;
  bool _lastIsVisible = false;
  bool _lastHasActiveSpan = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<_Token> _tokenize(String text) {
    if (identical(text, _cachedFullText) || text == _cachedFullText) {
      return _cachedTokens;
    }
    final regex = RegExp(r'\S+');
    final out = <_Token>[];
    for (final m in regex.allMatches(text)) {
      out.add(_Token(m.start, m.end, m.group(0) ?? ''));
    }
    _cachedFullText = text;
    _cachedTokens = out;
    return out;
  }

  bool _spanOverlaps(int aStart, int aEnd, int bStart, int bEnd) {
    if (aEnd <= bStart) return false;
    if (bEnd <= aStart) return false;
    return true;
  }

  void _scheduleEnsureVisible() {
    // Auto-follow respects [_userFollowing] — once the user manually scrolls,
    // we stop forcing the active word back into view. The pill (rendered
    // separately) is the explicit re-engage affordance.
    if (!_userFollowing) return;
    // Wait one frame so the new active GlobalKey is mounted with a layout box.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Pill tap: re-engage follow + jump to the active word right now.
  /// Bypasses the [_userFollowing] gate intentionally — the pill *is* the
  /// gate's reset switch.
  void _resumeFollowAndJump() {
    setState(() => _userFollowing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Called from [NotificationListener]. A non-idle [UserScrollNotification]
  /// is the cleanest signal of *user* drag/wheel/keyboard scroll —
  /// programmatic [Scrollable.ensureVisible] uses an animation controller and
  /// does NOT emit one, so there's no false-positive feedback loop with our
  /// own auto-scroll calls.
  void _handleUserScrollNotification(UserScrollNotification n) {
    if (n.direction != ScrollDirection.idle && _userFollowing) {
      setState(() => _userFollowing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(karaokeControllerProvider);

    // Edge-detect transitions and reset follow on:
    //   1. TTS just stopped (isSpeaking true → false), or
    //   2. Active span was just cleared (hasActiveSpan true → false), or
    //   3. Pane was just re-opened (isVisible false → true).
    // This guarantees the next utterance / pane open starts in clean follow
    // mode — the pill only ever appears as a result of an *explicit* user
    // scroll during a live session.
    final justStoppedSpeaking = _lastIsSpeaking && !state.isSpeaking;
    final justClearedSpan = _lastHasActiveSpan && !state.hasActiveSpan;
    final justBecameVisible = !_lastIsVisible && state.isVisible;
    if ((justStoppedSpeaking || justClearedSpan || justBecameVisible) &&
        !_userFollowing) {
      // Defer the setState to post-frame to avoid mutating during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_userFollowing) return;
        setState(() => _userFollowing = true);
      });
    }
    _lastIsSpeaking = state.isSpeaking;
    _lastIsVisible = state.isVisible;
    _lastHasActiveSpan = state.hasActiveSpan;

    // Side-effect: any state change schedules a scroll-into-view. The
    // PostFrameCallback above no-ops if the active key wasn't rendered, and
    // the call itself no-ops when [_userFollowing] is false.
    _scheduleEnsureVisible();

    final fullText = state.fullText;
    final hasContent = fullText.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.borderHairline, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(state),
            const Divider(height: 1, color: AppColors.borderHairline),
            Flexible(
              child: hasContent
                  ? _buildScrollingText(state)
                  : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(KaraokeState state) {
    final modeLabel = state.fallbackSentenceMode
        ? 'Sentence sync'
        : 'Word sync';
    final showSpeed =
        widget.currentSpeed != null && widget.onSpeedChange != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
      child: Row(
        children: [
          Icon(
            state.isSpeaking ? Icons.subtitles : Icons.subtitles_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Subtitle',
              style: AppTypography.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Hide the mode pill once the slider is mounted on phone-frame
          // widths to avoid overflow. The pill is informational only — the
          // speech rate slider is more important to the user mid-playback.
          if (!showSpeed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.iconBlueTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                modeLabel,
                style: AppTypography.captionBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          const Spacer(),
          if (showSpeed) ...[
            _SpeedSlider(
              value: widget.currentSpeed!,
              onChanged: widget.onSpeedChange!,
            ),
            const SizedBox(width: 4),
          ],
          Semantics(
            label: 'Hide closed captions',
            button: true,
            child: IconButton(
              splashRadius: 18,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () =>
                  ref.read(karaokeControllerProvider.notifier).hide(),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.graphic_eq, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Press Read to start closed captions',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The current word lights up as TTS speaks',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollingText(KaraokeState state) {
    final tokens = _tokenize(state.fullText);
    final spans = <InlineSpan>[];
    int cursor = 0;

    String? activeWord;

    // Base style for non-active text. Use bodyMedium / textPrimary so the
    // pane reads like prose. Higher contrast than bodySecondary.
    final baseStyle = AppTypography.bodyMedium.copyWith(
      color: AppColors.textPrimary,
      height: 1.6,
    );
    final activeStyle = AppTypography.bodyMedium.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w800,
      height: 1.6,
    );

    final tapHandler = widget.onWordTap;
    bool firstActiveSeen = false;

    for (final tok in tokens) {
      // Whitespace gap between previous token and this one.
      if (tok.start > cursor) {
        spans.add(
          TextSpan(
            text: state.fullText.substring(cursor, tok.start),
            style: baseStyle,
          ),
        );
      }

      final overlaps =
          state.hasActiveSpan &&
          _spanOverlaps(
            tok.start,
            tok.end,
            state.currentStart,
            state.currentEnd,
          );

      if (overlaps && activeWord == null) {
        activeWord = tok.text;
      }

      // First overlapping token carries the GlobalKey so ensureVisible scrolls
      // to the leading edge of the active span (matters in sentence mode where
      // multiple consecutive tokens are all highlighted).
      final isFirstActive = overlaps && !firstActiveSeen;
      if (isFirstActive) firstActiveSeen = true;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TappableWord(
            key: isFirstActive ? _activeKey : null,
            text: tok.text,
            wordStart: tok.start,
            isActive: overlaps,
            baseStyle: baseStyle,
            activeStyle: activeStyle,
            onTap: tapHandler,
          ),
        ),
      );
      cursor = tok.end;
    }
    // Trailing whitespace.
    if (cursor < state.fullText.length) {
      spans.add(
        TextSpan(text: state.fullText.substring(cursor), style: baseStyle),
      );
    }

    final liveLabel = activeWord != null
        ? 'Closed captions, current word: $activeWord'
        : 'Closed captions';

    // Pill is only meaningful while there's an active span to jump to AND
    // the user has scrolled away. It hides itself the moment follow is re-
    // engaged or speaking stops (the active span gets cleared).
    final showPill = state.isSpeaking && state.hasActiveSpan && !_userFollowing;

    return Semantics(
      label: liveLabel,
      liveRegion: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                _handleUserScrollNotification(n);
                return false; // never consume — Scrollbar still needs to see it
              },
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: false,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: SelectableRegion(
                    selectionControls: MaterialTextSelectionControls(),
                    child: RichText(
                      text: TextSpan(children: spans),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: IgnorePointer(
              ignoring: !showPill,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showPill ? 1.0 : 0.0,
                  child: _ResumeFollowPill(onTap: _resumeFollowAndJump),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spotify-style "jump to current lyric" pill. Floats over the captions while
/// the user has scrolled the pane away from the active word during playback.
/// Tapping it re-engages auto-follow and re-centers the active span.
class _ResumeFollowPill extends StatelessWidget {
  final VoidCallback onTap;
  const _ResumeFollowPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Resume closed caption follow',
      child: Material(
        color: AppColors.iconBlueTint,
        borderRadius: BorderRadius.circular(999),
        elevation: 4,
        shadowColor: const Color(0xFF000000).withValues(alpha: 0.18),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          // Vertical padding lifts the tap target to ≥48 dp tall once you add
          // the icon/text height — meets CLAUDE.md a11y contract.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.my_location,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Jump to current word',
                  style: AppTypography.captionBold.copyWith(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable inline word for click-to-seek scrubbing. Each token is its own
/// stateful island so hover + pulse animation stay local — no setState ripples
/// through the parent on every pointer enter/leave.
///
/// Tradeoff: tap target padding is intentionally small (6 px horizontal, 4 px
/// vertical) instead of WCAG 48 dp because expanding the box per word would
/// destroy text wrap and balloon the karaoke pane to 2x its natural height.
/// The active-span chip + hover tint give clear visual affordance, and users
/// can re-tap if they miss; the tradeoff is acceptable for v1.
class _TappableWord extends StatefulWidget {
  final String text;
  final int wordStart;
  final bool isActive;
  final TextStyle baseStyle;
  final TextStyle activeStyle;
  final void Function(int wordStart)? onTap;

  const _TappableWord({
    super.key,
    required this.text,
    required this.wordStart,
    required this.isActive,
    required this.baseStyle,
    required this.activeStyle,
    this.onTap,
  });

  @override
  State<_TappableWord> createState() => _TappableWordState();
}

class _TappableWordState extends State<_TappableWord> {
  bool _hovered = false;
  bool _pulsing = false;

  void _handleTap() {
    final cb = widget.onTap;
    if (cb == null) return;
    // Selection click is the lighter haptic — fits the "scrubbing" gesture
    // better than lightImpact (which feels like a button press, too heavy
    // when chained across multiple word taps).
    if (!kIsWeb) {
      HapticFeedback.selectionClick();
    }
    if (mounted) {
      setState(() => _pulsing = true);
    }
    // 150 ms forward + a tick to settle the AnimatedScale back to 1.0. The
    // scale animation drives off the bool, so we just flip it back; the
    // scheduled Future is robust to dispose because of mounted check.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _pulsing = false);
    });
    cb(widget.wordStart);
  }

  @override
  Widget build(BuildContext context) {
    // Active pill takes precedence over hover tint. iconBlueTint at full alpha
    // is the active color; the same token at ~40% alpha is the hover tint —
    // gives a faint preview of "this is what would highlight if you tapped".
    final Color? bg = widget.isActive
        ? AppColors.iconBlueTint
        : (_hovered ? AppColors.iconBlueTint.withValues(alpha: 0.4) : null);

    final Widget pill = AnimatedScale(
      scale: _pulsing ? 1.10 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.text,
          style: widget.isActive ? widget.activeStyle : widget.baseStyle,
        ),
      ),
    );

    final interactive = widget.onTap != null;

    Widget child = pill;
    child = MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? _handleTap : null,
        child: child,
      ),
    );

    return Semantics(
      button: interactive,
      label: interactive ? 'Jump to: ${widget.text}' : widget.text,
      child: child,
    );
  }
}

/// Compact in-header slider for live speech-rate adjustment. Range 0.5–2.0x;
/// the host screen maps that to whatever scale its TTS engine accepts.
///
/// Visual width caps at 120 dp so we still fit on the 412dp phone-frame.
class _SpeedSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SpeedSlider({required this.value, required this.onChanged});

  static const double _min = 0.5;
  static const double _max = 2.0;

  @override
  Widget build(BuildContext context) {
    // Clamp incoming value to the slider's range so a stale persisted rate
    // outside the new bounds doesn't crash the Slider invariant.
    final clamped = value.clamp(_min, _max);
    return SizedBox(
      width: 140,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${clamped.toStringAsFixed(1)}x',
              style: AppTypography.captionBold.copyWith(
                color: AppColors.primary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              slider: true,
              value: '${clamped.toStringAsFixed(1)}x speech rate',
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: clamped,
                  min: _min,
                  max: _max,
                  divisions: 15,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.borderSubtle,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
