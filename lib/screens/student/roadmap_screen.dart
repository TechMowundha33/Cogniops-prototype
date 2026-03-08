import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});
  @override State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _allRoadmaps = [];
  bool _loadingList = true;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    setState(() => _loadingList = true);
    try {
      final maps = await _api.getAllRoadmaps();
      if (maps.isEmpty) {
        final single = await _api.getRoadmap();
        _allRoadmaps = single != null ? [single] : [];
      } else {
        _allRoadmaps = maps;
      }
    } catch (_) { _allRoadmaps = []; }
    if (mounted) setState(() => _loadingList = false);
  }

  void _openGenerator() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _GeneratorScreen(onSaved: (roadmap) {
        setState(() => _allRoadmaps.insert(0, roadmap));
        // Reload from backend to confirm save
        Future.delayed(const Duration(milliseconds: 500), _loadAll);
      }),
    ));
  }

  void _openDetail(Map<String, dynamic> roadmap, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DetailScreen(
        roadmap: roadmap,
        onUpdated: (u) => setState(() => _allRoadmaps[index] = u),
        onDeleted: ()  => setState(() => _allRoadmaps.removeAt(index)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.map_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Roadmaps', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
            Text('Tap any roadmap to track progress', style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
          ])),
          GestureDetector(
            onTap: _openGenerator,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text('New', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loadingList
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : _allRoadmaps.isEmpty
                ? _empty(textColor, subColor)
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    color: AppColors.accent,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _allRoadmaps.length,
                      itemBuilder: (_, i) => _RoadmapCard(
                        roadmap: _allRoadmaps[i],
                        onTap: () => _openDetail(_allRoadmaps[i], i),
                      ),
                    ),
                  ),
      ),
    ]);
  }

  Widget _empty(Color text, Color sub) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🗺️', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text('No roadmaps yet', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: text)),
        const SizedBox(height: 8),
        Text('Create a personalised learning roadmap\nand track your progress week by week.',
            style: GoogleFonts.dmSans(fontSize: 13, color: sub, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _openGenerator,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Generate My First Roadmap 🚀',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    ));
  }
}

// ── List card ──────────────────────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  final Map<String, dynamic> roadmap;
  final VoidCallback onTap;
  const _RoadmapCard({required this.roadmap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text   = isDark ? AppColors.darkText    : AppColors.lightText;
    final sub    = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card   = isDark ? AppColors.darkCard     : AppColors.lightCard;

    List weeks = [];
    final rawWeeks = roadmap['weeks'];
    if (rawWeeks is String) { try { weeks = jsonDecode(rawWeeks) as List; } catch (_) {} }
    else if (rawWeeks is List) { weeks = rawWeeks; }

    final total  = weeks.length;
    final done   = weeks.where((w) => (w as Map)['done'] == true).length;
    final pct    = total > 0 ? done / total : 0.0;
    final title  = roadmap['title'] as String? ?? roadmap['goal'] as String? ?? 'Roadmap';
    final goal   = roadmap['goal'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: pct >= 1.0
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [AppColors.accent.withOpacity(0.2), AppColors.accentAlt.withOpacity(0.2)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(pct >= 1.0 ? '🏆' : '📚', style: const TextStyle(fontSize: 20)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (goal.isNotEmpty && goal != title)
                Text(goal, style: GoogleFonts.dmSans(fontSize: 11, color: sub),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: pct >= 1.0 ? AppColors.accentGreen.withOpacity(0.15) : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$done/$total wks',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                      color: pct >= 1.0 ? AppColors.accentGreen : AppColors.accent)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: sub, size: 20),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, backgroundColor: border,
              valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? AppColors.accentGreen : AppColors.accent),
              minHeight: 6,
            )),
          const SizedBox(height: 4),
          Text('${(pct * 100).round()}% complete — $total weeks',
              style: GoogleFonts.dmSans(fontSize: 10, color: sub)),
        ]),
      ),
    );
  }
}

// ─── Generator ───────────────────────────────────────────────────────────────
class _GeneratorScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onSaved;
  const _GeneratorScreen({required this.onSaved});
  @override State<_GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<_GeneratorScreen> {
  final _ctrl = TextEditingController();
  final _api  = ApiService();
  bool    _loading = false;
  String? _error;
  String  _sel = '8 weeks';

  final _durs = [
    {'label': '2 weeks',  'emoji': '⚡', 'desc': 'Sprint'},
    {'label': '4 weeks',  'emoji': '🎯', 'desc': 'Month'},
    {'label': '8 weeks',  'emoji': '📚', 'desc': 'Balanced'},
    {'label': '3 months', 'emoji': '🚀', 'desc': 'Deep'},
    {'label': '6 months', 'emoji': '🏆', 'desc': 'Mastery'},
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    if (_ctrl.text.trim().isEmpty) return;
    final goal = _ctrl.text.trim();
    setState(() { _loading = true; _error = null; });
    try {
      final weekCount = {'2 weeks': 2, '4 weeks': 4, '8 weeks': 8, '3 months': 12, '6 months': 24}[_sel] ?? 8;
      final raw  = await BedrockService().generateRoadmap('$goal in $_sel ($weekCount weeks total)');
      final data = jsonDecode(raw.replaceAll(RegExp(r'```json|```'), '').trim()) as Map<String, dynamic>;

      List<Map<String, dynamic>> weeks = [];
      final rawW = data['weeks'] ?? (data['data'] as Map?)?['weeks'];
      if (rawW is List) weeks = rawW.map((w) => Map<String, dynamic>.from(w as Map)).toList();

      final title = (data['title'] ?? (data['data'] as Map?)?['title'] ?? goal) as String;
      final rmId  = 'rm_${DateTime.now().millisecondsSinceEpoch}';
      final roadmap = {'roadmapId': rmId, 'goal': goal, 'title': title, 'weeks': weeks,
          'duration': _sel, 'createdAt': DateTime.now().toIso8601String()};

      await _api.saveRoadmap(goal: goal, title: title, weeks: weeks, roadmapId: rmId);

      if (mounted) {
        widget.onSaved(roadmap);
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _DetailScreen(roadmap: roadmap, onUpdated: (_) {}, onDeleted: () {})));
      }
    } catch (e) {
      setState(() { _error = 'Generation failed — try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0, leading: BackButton(color: textColor),
        title: Text('New Roadmap', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: textColor)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: border)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What do you want to learn?', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: TextField(
              controller: _ctrl, style: GoogleFonts.dmSans(color: textColor, fontSize: 14),
              maxLines: 3, minLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. AWS Solutions Architect, Kubernetes, Docker, CI/CD…',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: subColor),
                contentPadding: const EdgeInsets.all(16), border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 24),
          Text('How long do you have?', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          SizedBox(height: 96, child: ListView.builder(
            scrollDirection: Axis.horizontal, itemCount: _durs.length,
            itemBuilder: (_, i) {
              final d = _durs[i];
              final sel = _sel == d['label'];
              return GestureDetector(
                onTap: () => setState(() => _sel = d['label']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 10),
                  width: 88,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.accent : card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? AppColors.accent : border, width: sel ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    Text(d['emoji']!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 3),
                    Text(d['label']!, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : textColor), textAlign: TextAlign.center),
                    Text(d['desc']!, style: GoogleFonts.dmSans(fontSize: 9,
                        color: sel ? Colors.white70 : subColor), textAlign: TextAlign.center),
                  ]),
                ),
              );
            },
          )),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
              child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt_rounded, size: 18),
              label: Text(_loading ? 'Generating roadmap…' : 'Generate My Roadmap ⚡',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}

// ─── Detail ──────────────────────────────────────────────────────────────────
class _DetailScreen extends StatefulWidget {
  final Map<String, dynamic> roadmap;
  final void Function(Map<String, dynamic>) onUpdated;
  final VoidCallback onDeleted;
  const _DetailScreen({required this.roadmap, required this.onUpdated, required this.onDeleted});
  @override State<_DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<_DetailScreen> {
  final _api = ApiService();
  late List<Map<String, dynamic>> _weeks;
  late String _title, _goal, _roadmapId;
  final Map<int, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _title     = widget.roadmap['title'] as String? ?? widget.roadmap['goal'] as String? ?? 'Roadmap';
    _goal      = widget.roadmap['goal'] as String? ?? '';
    _roadmapId = widget.roadmap['roadmapId'] as String? ?? '';
    final rawW = widget.roadmap['weeks'];
    if (rawW is String) {
      try { _weeks = (jsonDecode(rawW) as List).map((w) => Map<String, dynamic>.from(w as Map)).toList(); }
      catch (_) { _weeks = []; }
    } else if (rawW is List) {
      _weeks = rawW.map((w) => Map<String, dynamic>.from(w as Map)).toList();
    } else { _weeks = []; }
  }

  Future<void> _toggle(int i, bool done) async {
    setState(() => _weeks[i]['done'] = done);
    try {
      await _api.markWeekDone(i, done, roadmapId: _roadmapId.isNotEmpty ? _roadmapId : null);
      widget.onUpdated({...widget.roadmap, 'weeks': _weeks});
    } catch (_) {}
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Roadmap'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ));
    if (ok == true && mounted) {
      if (_roadmapId.isNotEmpty) await _api.deleteRoadmap(_roadmapId);
      widget.onDeleted();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;

    final total = _weeks.length;
    final done  = _weeks.where((w) => w['done'] == true).length;
    final pct   = total > 0 ? done / total : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0, leading: BackButton(color: textColor),
        title: Text(_title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: textColor, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: _delete)],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: border)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Progress banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.1), AppColors.accentAlt.withOpacity(0.06)]),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_goal.isNotEmpty ? _goal : _title,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 4),
                  Text('$done of $total weeks completed', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
                ])),
                Text('${(pct * 100).round()}%',
                    style: GoogleFonts.spaceMono(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.accent)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct, backgroundColor: border,
                  valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? AppColors.accentGreen : AppColors.accent),
                  minHeight: 8,
                )),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Weekly Plan', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),

          ..._weeks.asMap().entries.map((e) {
            final i = e.key; final w = e.value;
            final isDone   = w['done'] == true;
            final expanded = _expanded[i] ?? false;
            final topics   = (w['topics'] as List? ?? []).cast<String>();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDone ? AppColors.accentGreen.withOpacity(0.35) : border)),
              child: Column(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _expanded[i] = !expanded),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => _toggle(i, !isDone),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: isDone ? AppColors.accentGreen : Colors.transparent,
                            border: Border.all(color: isDone ? AppColors.accentGreen : subColor, width: 2),
                            shape: BoxShape.circle,
                          ),
                          child: isDone
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : Center(child: Text('${i + 1}', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: subColor))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Week ${w['week'] ?? i + 1}',
                            style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
                        Text(w['title'] as String? ?? 'Week ${i + 1}',
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
                                color: isDone ? subColor : textColor,
                                decoration: isDone ? TextDecoration.lineThrough : null)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDone ? AppColors.accentGreen.withOpacity(0.15) : AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(isDone ? '✅ Done' : '${topics.length} topics',
                            style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
                                color: isDone ? AppColors.accentGreen : AppColors.accent)),
                      ),
                      const SizedBox(width: 6),
                      Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: subColor, size: 20),
                    ]),
                  ),
                ),
                if (expanded && topics.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(54, 0, 14, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: topics.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(margin: const EdgeInsets.only(top: 5), width: 5, height: 5,
                              decoration: BoxDecoration(
                                  color: isDone ? AppColors.accentGreen : AppColors.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t, style: GoogleFonts.dmSans(fontSize: 12, color: subColor, height: 1.4))),
                        ]),
                      )).toList()),
                  ),
              ]),
            );
          }),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}


























