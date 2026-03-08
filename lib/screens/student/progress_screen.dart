import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;

    final weekData = [20.0, 45.0, 30.0, 70.0, 55.0, 80.0, 65.0];
    final maxVal = weekData.reduce((a, b) => a > b ? a : b);

    final badges = [
      ('🏆', 'First Quiz', true), ('🔥', '7-Day Streak', true),
      ('⚡', 'Speed Learner', true), ('🌟', 'AWS Guru', true),
      ('🚀', 'Top 10%', false), ('💎', 'Expert Badge', false),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats row
        Row(children: [
          StatCard(label: 'Total XP', value: '${user.xp}', emoji: '⚡', color: AppColors.accent),
          const SizedBox(width: 8),
          StatCard(label: 'Day Streak', value: '${user.streak}', emoji: '🔥', color: AppColors.accentAmber),
          const SizedBox(width: 8),
          const StatCard(label: 'Modules', value: '12', emoji: '✅', color: AppColors.accentGreen),
          const SizedBox(width: 8),
          const StatCard(label: 'Quiz Avg', value: '84%', emoji: '📊', color: AppColors.accentAlt),
        ]),
        const SizedBox(height: 20),

        // Weekly activity chart
        const SectionTitle('Weekly Activity'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weekData.asMap().entries.map((e) {
                  final weeks = ['W1','W2','W3','W4','W5','W6','W7'];
                  final barH = (e.value / maxVal) * 85;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: barH,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.accent, AppColors.accentAlt],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(weeks[e.key], style: GoogleFonts.dmSans(fontSize: 10, color: subColor)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // XP Bar
        const SectionTitle('Level Progress'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Level 8 — Cloud Explorer',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                  Text('${user.xp} / 2000 XP to Level 9',
                    style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
                ]),
              ),
              const Text('☁️', style: TextStyle(fontSize: 28)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (user.xp / 2000).clamp(0.0, 1.0),
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 10,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Badges
        const SectionTitle('Achievements'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
          ),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: badges.map((b) => _BadgeTile(
              emoji: b.$1, name: b.$2, earned: b.$3,
              textColor: textColor,
              border: border,
            )).toList(),
          ),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final String emoji, name;
  final bool earned;
  final Color textColor, border;

  const _BadgeTile({
    required this.emoji, required this.name,
    required this.earned, required this.textColor, required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1.0 : 0.35,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? AppColors.accent.withOpacity(0.4) : border,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(name,
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: earned ? textColor : AppColors.darkTextMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }
}
