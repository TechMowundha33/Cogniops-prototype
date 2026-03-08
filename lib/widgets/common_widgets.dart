import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

// Gradient Button 
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double? width;
  final List<Color> colors;
  final Widget? icon;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.width,
    this.colors = const [AppColors.accent, AppColors.accentAlt],
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: loading
            ? const Center(child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5,
                ),
              ))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(label,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

//  App Card 
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? bgColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = bgColor ?? (isDark ? AppColors.darkCard : AppColors.lightCard);
    final border = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}

//  Section Title 
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

//  Color Badge 
class ColorBadge extends StatelessWidget {
  final String label;
  final Color color;

  const ColorBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
        style: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w600, color: color,
        ),
      ),
    );
  }
}

// Progress Bar 
class AppProgressBar extends StatelessWidget {
  final String label;
  final double value; // 0–1
  final Color color;
  final String? trailing;

  const AppProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 12, color: sub),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(trailing ?? '${(value * 100).toInt()}%',
          style: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w600, color: color,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

//  Avatar Widget 
class AppAvatar extends StatelessWidget {
  final String letter;
  final double size;

  const AppAvatar({super.key, required this.letter, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(letter,
          style: GoogleFonts.dmSans(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

//  Stat Card 
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value,
            style: GoogleFonts.spaceMono(
              fontSize: 20, fontWeight: FontWeight.w700, color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }
}

// Copy Code Block 
class CodeBlock extends StatefulWidget {
  final String code;
  final String? filename;

  const CodeBlock({super.key, required this.code, this.filename});

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.darkSurfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Text(
              widget.filename ?? 'code',
              style: GoogleFonts.spaceMono(fontSize: 12, color: AppColors.darkTextSub),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _copy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 13, color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(_copied ? 'Copied!' : 'Copy',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 280,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(widget.code,
              style: GoogleFonts.spaceMono(
                fontSize: 12, color: AppColors.codeText, height: 1.7,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

//  Loading Spinner 
class AppLoader extends StatelessWidget {
  final String? message;
  const AppLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(
          color: AppColors.accent, strokeWidth: 2.5,
        ),
        if (message != null) ...[
          const SizedBox(height: 14),
          Text(message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ]),
    );
  }
}

// Empty State
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
