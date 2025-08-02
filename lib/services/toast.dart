import "package:flutter/material.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";

enum ToastType { success, waiting, error, info }

class ToastService {
  static Future<void> show(
    String message,
    BuildContext context, {
    ToastType type = ToastType.success,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg =
        theme.colorScheme.surface.withValues(alpha: isDark ? 0.95 : 0.98);
    final border = theme.colorScheme.outline.withValues(alpha: 0.2);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );

    final (IconData icon, Color iconColor) = switch (type) {
      ToastType.success => (
          Icons.check_circle_rounded,
          theme.colorScheme.primary
        ),
      ToastType.waiting => (
          Icons.hourglass_top_rounded,
          theme.colorScheme.secondary
        ),
      ToastType.error => (Icons.error_rounded, theme.colorScheme.error),
      ToastType.info => (
          Icons.info_outline_rounded,
          theme.colorScheme.tertiary
        ),
    };

    await SmartDialog.showToast(
      message,
      builder: (_) => SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: bg,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: border),
                  borderRadius: BorderRadius.circular(12),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message,
                        style: textStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
