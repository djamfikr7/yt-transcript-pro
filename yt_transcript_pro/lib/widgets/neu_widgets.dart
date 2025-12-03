import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Modern Neumorphic Card/Panel
class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;

  const NeuCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppTheme.getShadows(context),
      ),
      child: child,
    );
  }
}

/// Modern Neumorphic Button
class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool isCircle;

  const NeuButton({
    Key? key,
    required this.child,
    this.onTap,
    this.color,
    this.size = 60,
    this.isCircle = true,
  }) : super(key: key);

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? AppTheme.getSurface(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.isCircle ? null : BorderRadius.circular(16),
          boxShadow: AppTheme.getShadows(context, pressed: _isPressed),
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

/// Icon Button with Label (like in reference)
class NeuIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  const NeuIconButton({
    Key? key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuButton(
          onTap: onTap,
          child: Icon(icon, color: iconColor ?? AppTheme.green, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// Modern Input Field
class NeuTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final bool obscureText;

  const NeuTextField({
    Key? key,
    required this.hint,
    this.controller,
    this.prefixIcon,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.getShadows(context, pressed: true),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppTheme.iconGray)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

/// Transaction List Item (like in reference)
class TransactionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final bool isNegative;
  final IconData icon;

  const TransactionItem({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.isNegative = true,
    this.icon = Icons.shopping_bag_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.getBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.iconGray),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            '${isNegative ? '-' : '+'}$amount',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isNegative ? AppTheme.red : AppTheme.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress Ring (like in reference with green/orange gradient)
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final String centerText;

  const ProgressRing({
    Key? key,
    this.progress = 0.75,
    this.size = 180,
    this.strokeWidth = 12,
    this.centerText = '\$95,000',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.getBackground(context),
              boxShadow: AppTheme.getShadows(context, pressed: true),
            ),
          ),
          // Progress ring (simplified - actual gradient would need CustomPaint)
          SizedBox(
            width: size - 20,
            height: size - 20,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cash available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                centerText,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
