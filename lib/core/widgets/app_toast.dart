import 'dart:async';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppToastTone { success, error, warning, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  static SnackBar snackBar({
    Key? key,
    required Widget content,
    Color? backgroundColor,
    double? elevation,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? width,
    ShapeBorder? shape,
    SnackBarBehavior? behavior,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    Animation<double>? animation,
    VoidCallback? onVisible,
    DismissDirection dismissDirection = DismissDirection.up,
    Clip clipBehavior = Clip.hardEdge,
  }) {
    final tone = _toneFromColor(backgroundColor);
    final message = _messageFromContent(content);
    final normalized = _normalizeMessage(message, tone);

    return SnackBar(
      key: key,
      behavior: behavior ?? SnackBarBehavior.floating,
      elevation: elevation ?? 0,
      backgroundColor: Colors.transparent,
      width: width,
      margin: margin ?? _defaultMargin(),
      padding: padding ?? EdgeInsets.zero,
      shape:
          shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      duration: duration,
      animation: animation,
      onVisible: onVisible,
      dismissDirection: dismissDirection,
      clipBehavior: clipBehavior,
      content: _ToastCard(
        tone: tone,
        title: normalized.title,
        originalContent: message == null ? content : null,
        action: action,
      ),
    );
  }

  static void show(BuildContext context, SnackBar snackBar) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) return;
    
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }

    _activeTimer?.cancel();
    _activeEntry?.remove();

    final directionality = Directionality.maybeOf(navContext) ?? TextDirection.ltr;
    final resolvedMargin =
        (snackBar.margin ?? _defaultMargin()).resolve(directionality);
    
    final topPadding = MediaQuery.paddingOf(navContext).top;
    final topOffset = resolvedMargin.top + topPadding;
    
    final horizontalMargin = snackBar.width == null ? resolvedMargin.right : 0.0;

    final entry = OverlayEntry(
      builder: (overlayContext) {
        return _ToastOverlay(
          top: topOffset,
          left: resolvedMargin.left,
          right: horizontalMargin,
          width: snackBar.width,
          child: snackBar.content,
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);
    snackBar.onVisible?.call();

    _activeTimer = Timer(snackBar.duration, hide);
  }

  static void hide() {
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static SnackBar success(String message) =>
      snackBar(content: Text(message), backgroundColor: AppColors.success);

  static SnackBar error(String message) =>
      snackBar(content: Text(message), backgroundColor: AppColors.error);

  static SnackBar info(String message) =>
      snackBar(content: Text(message), backgroundColor: AppColors.info);

  static SnackBar warning(String message) =>
      snackBar(content: Text(message), backgroundColor: AppColors.warning);

  static AppToastTone _toneFromColor(Color? color) {
    if (color == AppColors.success) return AppToastTone.success;
    if (color == AppColors.error) return AppToastTone.error;
    if (color == AppColors.warning) return AppToastTone.warning;
    if (color == AppColors.info) return AppToastTone.info;
    return AppToastTone.info;
  }

  static String? _messageFromContent(Widget content) {
    if (content is Text) {
      return content.data ?? content.textSpan?.toPlainText();
    }
    return null;
  }

  static _NormalizedToast _normalizeMessage(String? raw, AppToastTone tone) {
    final fallbackTitle = switch (tone) {
      AppToastTone.success => 'Done',
      AppToastTone.error => 'Could not complete action',
      AppToastTone.warning => 'Please review',
      AppToastTone.info => 'Update',
    };

    if (raw == null || raw.trim().isEmpty) {
      return _NormalizedToast(title: fallbackTitle);
    }

    var message = raw.trim();
    if (tone == AppToastTone.error) {
      message = message
          .replaceFirst(
            RegExp(r'^(Error|Failed|Failure):\s*', caseSensitive: false),
            '',
          )
          .replaceFirst(
            RegExp(r'^(Upload failed|Failed):\s*', caseSensitive: false),
            '',
          );
    }

    return _NormalizedToast(title: message);
  }

  static EdgeInsets _defaultMargin() {
    return const EdgeInsets.fromLTRB(16, 16, 16, 0); // Reduced from 96 to 16 because safe area top is now added dynamically
  }
}

extension AppToastMessenger on ScaffoldMessengerState {
  void showAppToast(SnackBar snackBar) {
    AppToast.show(context, snackBar);
  }
}

class _ToastOverlay extends StatefulWidget {
  final double top;
  final double left;
  final double right;
  final double? width;
  final Widget child;

  const _ToastOverlay({
    required this.top,
    required this.left,
    required this.right,
    required this.width,
    required this.child,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.width == null ? widget.right : null,
      child: IgnorePointer(
        ignoring: false,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            bottom: false,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.width ?? 640,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final AppToastTone tone;
  final String title;
  final Widget? originalContent;
  final SnackBarAction? action;

  const _ToastCard({
    required this.tone,
    required this.title,
    this.originalContent,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ToastColors.forTone(tone);

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('app-toast-card'),
        constraints: const BoxConstraints(minHeight: 50),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: colors.accent.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 4, height: 50, color: colors.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colors.badge,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForTone(tone),
                          color: colors.accent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: originalContent != null
                            ? DefaultTextStyle(
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                                child: originalContent!,
                              )
                            : Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                      ),
                      if (action != null) ...[const SizedBox(width: 8), action!],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForTone(AppToastTone tone) {
    return switch (tone) {
      AppToastTone.success => Icons.check_rounded,
      AppToastTone.error => Icons.priority_high_rounded,
      AppToastTone.warning => Icons.warning_amber_rounded,
      AppToastTone.info => Icons.info_outline_rounded,
    };
  }
}

class _ToastColors {
  final Color surface;
  final Color border;
  final Color badge;
  final Color accent;

  const _ToastColors({
    required this.surface,
    required this.border,
    required this.badge,
    required this.accent,
  });

  static _ToastColors forTone(AppToastTone tone) {
    return switch (tone) {
      AppToastTone.success => _ToastColors(
        surface: const Color(0xFFF0FDF4),
        border: const Color(0xFFBBF7D0),
        badge: const Color(0xFFD1FAE5),
        accent: AppColors.success,
      ),
      AppToastTone.error => _ToastColors(
        surface: const Color(0xFFFEF2F2),
        border: const Color(0xFFFECACA),
        badge: const Color(0xFFFEE2E2),
        accent: AppColors.error,
      ),
      AppToastTone.warning => _ToastColors(
        surface: const Color(0xFFFFFBEB),
        border: const Color(0xFFFDE68A),
        badge: const Color(0xFFFEF3C7),
        accent: AppColors.warning,
      ),
      AppToastTone.info => _ToastColors(
        surface: AppColors.surface,
        border: AppColors.cardBorder,
        badge: AppColors.primaryLight,
        accent: AppColors.primaryDark,
      ),
    };
  }
}

class _NormalizedToast {
  final String title;

  const _NormalizedToast({required this.title});
}
