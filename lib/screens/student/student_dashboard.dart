import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _api = ApiService();
  List<Map<String, dynamic>> _quizResults = [];
  Map<String, dynamic>? _roadmap;
  List<Map<String, dynamic>> _allRoadmaps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results  = await _api.getQuizResults(limit: 5);
      final roadmaps = await _api.getAllRoadmaps();
      final roadmap  = roadmaps.isNotEmpty ? roadmaps.first : await _api.getRoadmap();
      if (mounted) setState(() {
        _quizResults  = results;
        _roadmap      = roadmap;
        _allRoadmaps  = roadmaps;
        _loading      = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _modulesCompleted {
    if (_allRoadmaps.isEmpty && _roadmap == null) return 0;
    try {
      int total = 0;
      final roadmaps = _allRoadmaps.isNotEmpty ? _allRoadmaps : (_roadmap != null ? [_roadmap!] : []);
      for (final r in roadmaps) {
        final raw = r['weeks'];
        List weeks = raw is String ? [] : (raw as List? ?? []);
        total += weeks.where((w) => (w as Map)['done'] == true).length;
      }
      return total;
    } catch (_) { return 0; }
  }

  double get _avgScore {
    if (_quizResults.isEmpty) return 0;
    final total = _quizResults.fold<int>(0, (s, r) => s + (r['pct'] as num? ?? 0).toInt());
    return total / _quizResults.length;
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final user      = auth.user!;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final hour      = DateTime.now().hour;
    final greeting  = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final textColor = isDark ? AppColors.darkText       : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub    : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder     : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard       : AppColors.lightCard;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Welcome Banner ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withOpacity(0.15), AppColors.accentAlt.withOpacity(0.08)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🚀 $greeting, ${user.name.split(' ').first}!',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Your cloud journey continues. Keep up the momentum!',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: textColor, height: 1.4)),
              const SizedBox(height: 8),
              RichText(text: TextSpan(
                style: GoogleFonts.dmSans(fontSize: 13, color: subColor, height: 1.5),
                children: [
                  const TextSpan(text: "You're on a "),
                  TextSpan(text: '${user.streak}-day streak 🔥',
                      style: const TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.w700)),
                  const TextSpan(text: " — Keep going!"),
                ],
              )),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(children: [
                  _StatCard(label: 'XP Points',    value: user.xp.toString(),       emoji: '⚡', color: AppColors.accent),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Day Streak',   value: '${user.streak}',         emoji: '🔥', color: AppColors.accentAmber),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Modules Done', value: '$_modulesCompleted',     emoji: '✅', color: AppColors.accentGreen),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Avg Score',
                      value: _quizResults.isEmpty ? '—' : '${_avgScore.round()}%',
                      emoji: '🏅', color: AppColors.accentAlt),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Quiz Progress ──────────────────────────────────────────
          const SectionTitle('Quiz Performance'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                : _quizResults.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No quizzes yet — take your first quiz!',
                            style: GoogleFonts.dmSans(fontSize: 13, color: subColor)),
                      ))
                    : Column(children: _quizResults.map((r) {
                        final pct = (r['pct'] as num? ?? 0).toInt();
                        final color = pct >= 80 ? AppColors.accentGreen
                            : pct >= 60 ? AppColors.accentAmber : AppColors.accentAlt;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: AppProgressBar(
                            label: '${r['topic'] ?? 'Quiz'} (${r['difficulty'] ?? ''}) — $pct%',
                            value: pct / 100,
                            color: color,
                          ),
                        );
                      }).toList()),
          ),
          const SizedBox(height: 24),

          // ── Roadmap Progress ───────────────────────────────────────
          const SectionTitle('My Roadmaps'),
          if (_loading)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
            )
          else if (_allRoadmaps.isEmpty && _roadmap == null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Center(child: Text('No roadmaps yet — go to the Roadmap tab to create one!',
                  style: GoogleFonts.dmSans(fontSize: 13, color: subColor))),
            )
          else
            ..._buildAllRoadmaps(isDark, textColor, subColor, border, card),
          const SizedBox(height: 24),

          // ── Recent Quiz Activity ───────────────────────────────────
          if (_quizResults.isNotEmpty) ...[
            const SectionTitle('Recent Activity'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(children: [
                for (int i = 0; i < _quizResults.length; i++) ...[
                  if (i > 0) Divider(color: border, height: 1),
                  _activityItem(
                    'Completed Quiz',
                    '${_quizResults[i]['topic']} — Score: ${_quizResults[i]['pct']}%',
                    _timeAgo(_quizResults[i]['createdAt'] as String? ?? ''),
                    '🧠', AppColors.accent, isDark,
                  ),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  List<Widget> _buildAllRoadmaps(bool isDark, Color textColor, Color subColor, Color border, Color card) {
    final roadmaps = _allRoadmaps.isNotEmpty ? _allRoadmaps : (_roadmap != null ? [_roadmap!] : []);
    return roadmaps.take(3).map((r) {
      try {
        final raw  = r['weeks'];
        final List weeks = raw is String ? [] : (raw as List? ?? []);
        final total = weeks.length;
        final done  = weeks.where((w) => (w as Map)['done'] == true).length;
        final pct   = total > 0 ? done / total : 0.0;
        final title = r['title'] as String? ?? r['goal'] as String? ?? 'Roadmap';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(pct >= 1.0 ? '🏆' : '📚', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('$done/$total', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                  color: pct >= 1.0 ? AppColors.accentGreen : AppColors.accent)),
            ]),
            const SizedBox(height: 8),
            AppProgressBar(label: '${(pct * 100).round()}% complete', value: pct,
                color: pct >= 1.0 ? AppColors.accentGreen : AppColors.accent),
          ]),
        );
      } catch (_) { return const SizedBox(); }
    }).toList();
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt   = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0)  return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) { return ''; }
  }

  Widget _activityItem(String action, String detail, String time, String emoji, Color color, bool isDark) {
    final sub  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final muted= isDark ? AppColors.darkTextMuted: AppColors.lightTextMuted;
    final text = isDark ? AppColors.darkText      : AppColors.lightText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: text), overflow: TextOverflow.ellipsis),
          Text(detail, style: GoogleFonts.dmSans(fontSize: 11, color: sub), overflow: TextOverflow.ellipsis),
        ])),
        Text(time, style: GoogleFonts.dmSans(fontSize: 11, color: muted)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.emoji, required this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final sub    = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Container(
      width: 90, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: sub, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }
}