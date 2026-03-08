import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 20),
        // Profile
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profile', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 16),
            Row(children: [
              AppAvatar(letter: user.avatarLetter, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                  Text(user.email, style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
                  const SizedBox(height: 6),
                  ColorBadge(
                    label: user.isDeveloper ? '💻 Developer Mode' : '🎓 Student Mode',
                    color: user.isDeveloper ? AppColors.accentGreen : AppColors.accent,
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentAmber.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_rounded, size: 14, color: AppColors.accentAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Role is locked at registration and cannot be changed.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accentAmber)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // Appearance
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Appearance', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Theme', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
                  Text('Currently: ${isDark ? "Dark mode" : "Light mode"}', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
                ]),
              ),
              GestureDetector(
                onTap: () => context.read<ThemeProvider>().toggle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.accent, borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Toggle', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        // Preferences
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Preferences', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 14),
            ...['Daily learning reminders', 'Streak notifications', 'Quiz completion summaries', 'New feature announcements']
                .asMap().entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: e.key < 3 ? Border(bottom: BorderSide(color: border)) : null,
              ),
              child: Row(children: [
                Expanded(child: Text(e.value, style: GoogleFonts.dmSans(fontSize: 13, color: textColor))),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 44, height: 24,
                    decoration: BoxDecoration(
                      color: e.key % 2 == 0 ? AppColors.accent : border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: e.key % 2 == 0 ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        width: 20, height: 20,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        // About
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About CogniOps', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 10),
            Text('Version 1.0.0 · AI Teammate for Cloud Builders\nPowered by AWS · Built with ❤️ for cloud engineers and learners worldwide.',
              style: GoogleFonts.dmSans(fontSize: 13, color: subColor, height: 1.6)),
          ]),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => context.read<AuthProvider>().logout(),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentAlt.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentAlt.withOpacity(0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.logout_rounded, color: AppColors.accentAlt, size: 18),
              const SizedBox(width: 8),
              Text('Sign Out', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accentAlt)),
            ]),
          ),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}
