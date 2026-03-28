import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glassmorphic container with frosted glass effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? color;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 10,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }

    return container;
  }
}

/// Gradient button with glow effect
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final IconData? icon;
  final List<Color>? colors;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.icon,
    this.colors,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.colors ?? [AppTheme.primaryStart, AppTheme.primaryEnd];

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width ?? double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Online status indicator dot
class StatusDot extends StatelessWidget {
  final String status;
  final double size;

  const StatusDot({super.key, required this.status, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColor(),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.darkBg, width: 2),
        boxShadow: [
          BoxShadow(
            color: _getColor().withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case 'online':
        return AppTheme.online;
      case 'away':
        return AppTheme.away;
      case 'busy':
        return AppTheme.busy;
      default:
        return AppTheme.offline;
    }
  }
}

/// Avatar with online indicator
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final String status;
  final double size;
  final bool showStatus;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.status = 'offline',
    this.size = 44,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _getAvatarColors(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            ),
            child: imageUrl != null
                ? ClipOval(
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildInitials(),
                    ),
                  )
                : _buildInitials(),
          ),
          if (showStatus)
            Positioned(
              bottom: 0,
              right: 0,
              child: StatusDot(status: status, size: size * 0.3),
            ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    final initials = displayName.isNotEmpty
        ? displayName
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Color> _getAvatarColors() {
    final hash = displayName.hashCode;
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF06B6D4), const Color(0xFF14B8A6)],
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      [const Color(0xFF10B981), const Color(0xFF06B6D4)],
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
      [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
    ];
    return colors[hash.abs() % colors.length];
  }
}

/// Animated shimmer loading placeholder
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [
                Color(0xFF1E2A4A),
                Color(0xFF2A3A5C),
                Color(0xFF1E2A4A),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: const Alignment(-1, 0),
              end: const Alignment(2, 0),
            ),
          ),
        );
      },
    );
  }
}

/// Floating orb background decoration
class FloatingOrbs extends StatefulWidget {
  const FloatingOrbs({super.key});

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: Duration(seconds: 8 + i * 4),
        vsync: this,
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildOrb(
          0,
          AppTheme.primaryStart.withValues(alpha: 0.15),
          200,
          -50,
          -50,
        ),
        _buildOrb(
          1,
          AppTheme.accentCyan.withValues(alpha: 0.1),
          250,
          null,
          -100,
          right: -50,
        ),
        _buildOrb(
          2,
          AppTheme.primaryEnd.withValues(alpha: 0.1),
          180,
          null,
          null,
          bottom: -50,
          right: 50,
        ),
      ],
    );
  }

  Widget _buildOrb(
    int index,
    Color color,
    double size,
    double? top,
    double? left, {
    double? right,
    double? bottom,
  }) {
    return AnimatedBuilder(
      animation: _controllers[index],
      builder: (context, child) {
        final value = _controllers[index].value;
        return Positioned(
          top: top != null ? top + (value * 30 - 15) : null,
          left: left != null ? left + (value * 20 - 10) : null,
          right: right != null ? right + (value * 25 - 12.5) : null,
          bottom: bottom != null ? bottom + (value * 30 - 15) : null,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
      },
    );
  }
}
