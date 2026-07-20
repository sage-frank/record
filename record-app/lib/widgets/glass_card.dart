import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 毛玻璃效果卡片组件
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final Gradient? gradient;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 16.0,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.gradient,
  }) : super(key: key);

  @override
    Widget build(BuildContext context) {
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor?.withOpacity(opacity) ?? 
                       Colors.white.withOpacity(opacity),
                borderRadius: BorderRadius.circular(borderRadius),
                border: border ??
                        Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      );
    }
}

/// 现代化的卡片组件
class ModernCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool enableHover;

  const ModernCard({
    Key? key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.boxShadow,
    this.onTap,
    this.enableHover = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: gradient ?? AppTheme.cardGradient,
              boxShadow: boxShadow ?? [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 渐变卡片组件
class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GradientCard({
    Key? key,
    required this.child,
    required this.gradient,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 统计数字卡片
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? iconColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const StatsCard({
    Key? key,
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    this.iconColor,
    this.gradient,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ModernCard(
      onTap: onTap,
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.primaryGreen).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.heading2.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ..[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 进度环形卡片
class ProgressCard extends StatelessWidget {
  final String title;
  final double progress; // 0.0 - 1.0
  final String current;
  final String target;
  final Color? progressColor;
  final Widget? centerWidget;

  const ProgressCard({
    Key? key,
    required this.title,
    required this.progress,
    required this.current,
    required this.target,
    this.progressColor,
    this.centerWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = progressColor ?? AppTheme.primaryGreen;
    
    return ModernCard(
      child: Column(
        children: [
          Text(
            title,
            style: AppTextStyles.subtitle1,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                if (centerWidget != null)
                  centerWidget!
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        current,
                        style: AppTextStyles.heading3.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '/ $target',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}