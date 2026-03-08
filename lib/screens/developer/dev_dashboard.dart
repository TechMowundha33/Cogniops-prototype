import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class DevDashboard extends StatefulWidget {
  const DevDashboard({super.key});
  @override State<DevDashboard> createState() => _DevDashboardState();
}

class _DevDashboardState extends State<DevDashboard> {
  final _api = ApiService();
  List<Map<String, dynamic>> _sessions     = [];
  Map<String, dynamic>?      _progress;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getSessions(),
        _api.getProgress(),
      ]);
      if (mounted) {
        setState(() {
        _sessions  = results[0] as List<Map<String, dynamic>>;
        _progress  = results[1] as Map<String, dynamic>?;
        _loading   = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int    get _chatCount   => _sessions.length;
  int    get _xp          => (_progress?['xp'] as num?)?.toInt() ?? 0;
  int    get _streak      => (_progress?['streak'] as num?)?.toInt() ?? 0;

  // Derive "architectures generated" from session titles
  int get _archCount => _sessions.where((s) {
    final t = (s['title'] as String? ?? '').toLowerCase();
    return t.contains('architect') || t.contains('design') || t.contains('system');
  }).length;

  int get _tfCount => _sessions.where((s) {
    final t = (s['title'] as String? ?? '').toLowerCase();
    return t.contains('terraform') || t.contains('iac') || t.contains('hcl');
  }).length;

  @override
  Widget build(BuildContext context) {
    final user     = context.watch<AuthProvider>().user!;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;

    final tools = [
      ('🏗️', 'Architecture Generator', 'Design scalable AWS systems', AppColors.accent),
      ('🔧', 'Backend Designer',       'Code → AWS service suggestions', AppColors.accentGreen),
      ('📦', 'Terraform Generator',    'Auto-generate IaC scripts', AppColors.accentAmber),
      ('💰', 'Cost Estimator',         'AI + manual AWS cost breakdown', AppColors.accentAlt),
      ('🐛', 'Debug Assistant',        'Socratic error debugging', const Color(0xFFDC2626)),
      ('💬', 'AI Chat',               'Freeform AI conversations', Colors.purpleAccent),
    ];

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Welcome banner 
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.accentGreen.withOpacity(0.12),
                AppColors.accent.withOpacity(0.08),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentGreen.withOpacity(0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Developer Workspace', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentGreen)),
                  ]),
                ),
                const Spacer(),
                Text('⚡ ${_xp}xp', style: GoogleFonts.spaceMono(fontSize: 12, color: AppColors.accentAmber, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Text('🔥 $_streak days', style: GoogleFonts.spaceMono(fontSize: 12, color: AppColors.accentAlt, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Text('Welcome back, ${user.name.split(' ').first}!',
                  style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 4),
              Text('Your AI-powered cloud engineering suite is ready. What are we building today?',
                  style: GoogleFonts.dmSans(fontSize: 13, color: subColor, height: 1.5)),
              const SizedBox(height: 16),

              // Stat cards — dynamic data
              if (_loading)
                const Center(child: SizedBox(height: 48, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StatCard(label: 'AI Sessions',    value: '$_chatCount',  emoji: '💬', color: AppColors.accent),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Architectures',  value: '$_archCount',  emoji: '🏗️', color: AppColors.accentGreen),
                    const SizedBox(width: 10),
                    _StatCard(label: 'TF Sessions',    value: '$_tfCount',    emoji: '📦', color: AppColors.accentAmber),
                    const SizedBox(width: 10),
                    _StatCard(label: 'XP Earned',      value: '$_xp',         emoji: '⚡', color: AppColors.accentAlt),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 24),

          // Developer Tools grid 
          Text('Developer Tools', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: tools.map((t) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: t.$4.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(t.$1, style: const TextStyle(fontSize: 20))),
                ),
                const Spacer(),
                Text(t.$2, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(t.$3, style: GoogleFonts.dmSans(fontSize: 10, color: subColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            )).toList(),
          ),
          const SizedBox(height: 24),

          //  Recent Chat Sessions 
          Row(children: [
            Text('Recent Sessions', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
            const Spacer(),
            Text('${_sessions.length} total', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
          ]),
          const SizedBox(height: 12),

          if (_loading)
            Container(height: 120, alignment: Alignment.center,
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                child: const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          else if (_sessions.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(children: [
                const Text('💬', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text('No sessions yet', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                Text('Start a conversation to see history here', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
              ]),
            )
          else
            Container(
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(
                children: _sessions.take(5).toList().asMap().entries.map((e) {
                  final s     = e.value;
                  final title = s['title'] as String? ?? 'New chat';
                  final upd   = s['updatedAt'] as String? ?? '';
                  final diff  = upd.isNotEmpty ? DateTime.now().difference(DateTime.tryParse(upd) ?? DateTime.now()) : null;
                  final ago   = diff == null ? '' : diff.inDays > 0 ? '${diff.inDays}d ago' : diff.inHours > 0 ? '${diff.inHours}h ago' : 'Just now';
                  // pick emoji based on title
                  final emoji = title.toLowerCase().contains('terraform') ? '📦'
                      : title.toLowerCase().contains('architect') ? '🏗️'
                      : title.toLowerCase().contains('debug') || title.toLowerCase().contains('error') ? '🐛'
                      : title.toLowerCase().contains('cost') ? '💰'
                      : '💬';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: e.key < (_sessions.length.clamp(0, 5) - 1)
                          ? Border(bottom: BorderSide(color: border)) : null,
                    ),
                    child: Row(children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title, style: GoogleFonts.dmSans(fontSize: 13, color: textColor, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(ago, style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
                    ]),
                  );
                }).toList(),
              ),
            ),

          //  Quick Tips 
          const SizedBox(height: 24),
          Text('Quick Tips', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          ...[
            ('🏗️', 'Architecture', 'Describe your full app for best diagrams', AppColors.accent),
            ('📦', 'Terraform',    'Mention specific services (EC2, RDS, S3…) for accurate HCL', AppColors.accentAmber),
            ('🐛', 'Debug',       'Include exact error messages and status codes', const Color(0xFFDC2626)),
          ].map((tip) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: tip.$4.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: tip.$4.withOpacity(0.2))),
            child: Row(children: [
              Text(tip.$1, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tip.$2, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: tip.$4)),
                Text(tip.$3, style: GoogleFonts.dmSans(fontSize: 12, color: subColor, height: 1.4)),
              ])),
            ]),
          )),

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Container(
      width: 90, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.22))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.spaceMono(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: subColor, height: 1.2), maxLines: 2),
      ]),
    );
  }
}

