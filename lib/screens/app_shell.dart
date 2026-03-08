import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../services/bedrock_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/floating_assistant.dart';
// Student
import 'student/student_dashboard.dart';
import 'student/chat_screen.dart';
import 'student/roadmap_screen.dart';
import 'student/quiz_screen.dart';
import 'student/progress_screen.dart';
// Developer
import 'developer/dev_dashboard.dart';
import 'developer/architecture_screen.dart';
import 'developer/backend_designer_screen.dart';
import 'developer/terraform_screen.dart';
import 'developer/cost_estimator_screen.dart';
import 'developer/debug_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;

  // ── Screens that HIDE the floating assistant ──────────────────────
  // Student: hide on AI Chat(1), Quiz(3), Progress(4), Settings(90)
  // Dev: hide on ALL screens except Dashboard(0)
  static const _noFABStudent = {1, 3, 4, 90};
  static const _noFABDev    = {1, 2, 3, 4, 5, 6, 90};

  // ── Nav definitions ───────────────────────────────────────────────
  List<_NavItem> get _studentNav => [
    const _NavItem('Dashboard', Icons.dashboard_rounded),
    const _NavItem('AI Chat',   Icons.smart_toy_rounded),
    const _NavItem('Roadmap',   Icons.map_rounded),
    const _NavItem('Quiz',      Icons.quiz_rounded),
    const _NavItem('Progress',  Icons.bar_chart_rounded),
  ];

  List<_NavItem> get _devNav => [
    const _NavItem('Dashboard', Icons.grid_view_rounded),
    const _NavItem('AI Chat',   Icons.smart_toy_rounded),
    const _NavItem('Architect', Icons.account_tree_rounded),
    const _NavItem('Backend',   Icons.code_rounded),
    const _NavItem('Terraform', Icons.inventory_2_rounded),
    const _NavItem('Cost',      Icons.monetization_on_rounded),
    const _NavItem('Debug',     Icons.bug_report_rounded),
  ];

  static const int _settingsIdx = 90;

  Widget _screen(int idx, bool isDev) {
    if (idx == _settingsIdx) return const SettingsScreen();
    if (isDev) {
      switch (idx) {
        case 0: return const DevDashboard();
        case 1: return const ChatScreen();
        case 2: return const ArchitectureScreen();
        case 3: return const BackendDesignerScreen();
        case 4: return const TerraformScreen();
        case 5: return const CostEstimatorScreen();
        case 6: return const DebugScreen();
        default: return const DevDashboard();
      }
    }
    switch (idx) {
      case 0: return const StudentDashboard();
      case 1: return const ChatScreen();
      case 2: return const RoadmapScreen();
      case 3: return const QuizScreen();
      case 4: return const ProgressScreen();
      default: return const StudentDashboard();
    }
  }

  // Keeps all screens alive so chat history is preserved on tab switch
  Widget _buildScreens(bool isDev) {
    final screens = isDev
        ? [
            const DevDashboard(),
            const ChatScreen(),
            const ArchitectureScreen(),
            const BackendDesignerScreen(),
            const TerraformScreen(),
            const CostEstimatorScreen(),
            const DebugScreen(),
          ]
        : [
            const StudentDashboard(),
            const ChatScreen(),
            const RoadmapScreen(),
            const QuizScreen(),
            const ProgressScreen(),
          ];
    final safeIdx = _idx.clamp(0, screens.length - 1);
    return IndexedStack(index: safeIdx, children: screens);
  }

  // ── Profile popup ─────────────────────────────────────────────────
  void _showProfile(BuildContext ctx, bool isDev, bool isDark) {
    final user     = ctx.read<AuthProvider>().user!;
    final surfBg   = isDark ? AppColors.darkSurface    : AppColors.lightSurface;
    final textCol  = isDark ? AppColors.darkText       : AppColors.lightText;
    final subCol   = isDark ? AppColors.darkTextSub    : AppColors.lightTextSub;
    final bdrCol   = isDark ? AppColors.darkBorder     : AppColors.lightBorder;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: surfBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: bdrCol, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Avatar + info
          Row(children: [
            AppAvatar(letter: user.avatarLetter, size: 48),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: textCol)),
              Text(user.email, style: GoogleFonts.dmSans(fontSize: 12, color: subCol)),
              const SizedBox(height: 4),
              ColorBadge(label: isDev ? '💻 Developer' : '🎓 Student', color: AppColors.accent),
            ])),
          ]),
          const SizedBox(height: 20),
          Divider(color: bdrCol),
          const SizedBox(height: 8),

          // Theme toggle
          _ProfileTile(
            icon: isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
            label: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            color: AppColors.accentAmber,
            onTap: () { Navigator.pop(ctx); ctx.read<ThemeProvider>().toggle(); },
          ),
          // Settings
          _ProfileTile(
            icon: Icons.settings_rounded,
            label: 'Settings',
            color: AppColors.accent,
            onTap: () { Navigator.pop(ctx); setState(() => _idx = _settingsIdx); },
          ),
          // XP & streak (student only)
          if (!isDev)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: _StatPill('⚡ ${user.xp} XP', AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(child: _StatPill('🔥 ${user.streak} Day Streak', AppColors.accentAmber)),
              ]),
            ),
          const SizedBox(height: 4),
          // Sign out
          _ProfileTile(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: AppColors.accentAlt,
            onTap: () {
              Navigator.pop(ctx);
              // Clear chat session on logout
              ctx.read<ChatProvider>().clear();
              BedrockService.resetSession();
              ctx.read<AuthProvider>().logout();
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final user     = auth.user!;
    final isDev    = user.isDeveloper;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final navItems = isDev ? _devNav : _studentNav;

    final textCol  = isDark ? AppColors.darkText      : AppColors.lightText;
    final subCol   = isDark ? AppColors.darkTextSub   : AppColors.lightTextSub;
    final surface  = isDark ? AppColors.darkSurface   : AppColors.lightSurface;
    final sidebarBg= isDark ? AppColors.darkSidebar   : AppColors.lightSurface;
    final surfAlt  = isDark ? AppColors.darkSurfaceAlt: AppColors.lightSurfaceAlt;
    final border   = isDark ? AppColors.darkBorder    : AppColors.lightBorder;

    // Clamp index if mode switches
    final isSpecial = _idx >= 90;
    if (!isSpecial && _idx >= navItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _idx = 0);
      });
    }

    final showFAB = isDev ? !_noFABDev.contains(_idx) : !_noFABStudent.contains(_idx);
    final safeIdx = isSpecial ? 0 : _idx.clamp(0, navItems.length - 1);

    // Profile button
    Widget profileBtn() => GestureDetector(
      onTap: () => _showProfile(context, isDev, isDark),
      child: Stack(children: [
        AppAvatar(letter: user.avatarLetter, size: 34),
        Positioned(right: 0, bottom: 0, child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: AppColors.accentGreen, shape: BoxShape.circle,
            border: Border.all(color: surface, width: 1.5),
          ),
        )),
      ]),
    );

    return Scaffold(
      body: LayoutBuilder(builder: (ctx, constraints) {
        final isWide = constraints.maxWidth >= 768;

        // ── DESKTOP ──────────────────────────────────────────────────
        if (isWide) {
          return Row(children: [
            // Sidebar
            Container(
              width: 220,
              decoration: BoxDecoration(color: sidebarBg, border: Border(right: BorderSide(color: border))),
              child: Column(children: [
                SafeArea(bottom: false, child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Row(children: [
                      Container(width: 34, height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16)),
                      const SizedBox(width: 10),
                      Text('CogniOps', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: textCol)),
                    ]),
                  ),
                  Divider(color: border, height: 1),
                ])),
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  itemCount: navItems.length,
                  itemBuilder: (_, i) {
                    final sel = !isSpecial && i == _idx;
                    final item = navItems[i];
                    return GestureDetector(
                      onTap: () => setState(() => _idx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? AppColors.accent.withOpacity(0.3) : Colors.transparent),
                        ),
                        child: Row(children: [
                          Icon(item.icon, size: 18, color: sel ? AppColors.accent : subCol),
                          const SizedBox(width: 10),
                          Text(item.label, style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel ? AppColors.accent : subCol,
                          )),
                        ]),
                      ),
                    );
                  },
                )),
                // User card
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: surfAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                  child: Row(children: [
                    profileBtn(),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: textCol), overflow: TextOverflow.ellipsis),
                      Text(isDev ? '💻 Dev' : '🎓 Student', style: GoogleFonts.dmSans(fontSize: 10, color: subCol)),
                    ])),
                  ]),
                ),
                const SafeArea(top: false, child: SizedBox(height: 0)),
              ]),
            ),
            // Main content
            Expanded(child: Stack(children: [
              Column(children: [
                // Top bar
                Container(
                  height: 56, padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
                  child: Row(children: [
                    Text(
                      isSpecial ? 'Settings' : navItems[safeIdx].label,
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: textCol),
                    ),
                    const Spacer(),
                    if (user.isStudent) ...[
                      ColorBadge(label: '⚡ ${user.xp} XP', color: AppColors.accent),
                      const SizedBox(width: 8),
                      ColorBadge(label: '🔥 ${user.streak} Days', color: AppColors.accentAmber),
                      const SizedBox(width: 12),
                    ],
                    profileBtn(),
                  ]),
                ),
                Expanded(child: _idx == _settingsIdx ? const SettingsScreen() : _buildScreens(isDev)),
              ]),
              if (showFAB) const Positioned(right: 20, bottom: 20, child: FloatingAssistant()),
            ])),
          ]);
        }

        // ── MOBILE ───────────────────────────────────────────────────
        return Column(children: [
          Expanded(child: Stack(children: [
            Column(children: [
              // Top bar
              SafeArea(bottom: false, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
                child: Row(children: [
                  Container(width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14)),
                  const SizedBox(width: 8),
                  Text('CogniOps', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: textCol)),
                  const Spacer(),
                  if (user.isStudent) ...[
                    ColorBadge(label: '⚡ ${user.xp} XP', color: AppColors.accent),
                    const SizedBox(width: 6),
                  ],
                  profileBtn(),
                ]),
              )),
              Expanded(child: _idx == _settingsIdx ? const SettingsScreen() : _buildScreens(isDev)),
            ]),
            if (showFAB) const Positioned(right: 14, bottom: 10, child: FloatingAssistant()),
          ])),

          // Bottom nav
          Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border(top: BorderSide(color: border)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: navItems.asMap().entries.map((e) {
                      final i = e.key; final item = e.value;
                      final sel = !isSpecial && i == _idx;
                      return GestureDetector(
                        onTap: () => setState(() => _idx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 72,
                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(item.icon, size: 20, color: sel ? AppColors.accent : subCol),
                            const SizedBox(height: 2),
                            Text(item.label,
                              style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w600,
                                  color: sel ? AppColors.accent : subCol),
                              overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.center,
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _NavItem { final String label; final IconData icon; const _NavItem(this.label, this.icon); }

class _ProfileTile extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = isDark ? AppColors.darkText : AppColors.lightText;
    return ListTile(
      contentPadding: EdgeInsets.zero, dense: true,
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: textCol)),
      trailing: Icon(Icons.chevron_right_rounded, color: color, size: 18),
      onTap: onTap,
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label; final Color color;
  const _StatPill(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Center(child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
    );
  }
}