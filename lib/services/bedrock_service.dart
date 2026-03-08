import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import 'package:cogniops/providers/auth_service.dart';


// AgentResponse — parsed from cogniops_agent.py Lambda

class AgentResponse {
  final String type;
  final String assistantText;
  final Map<String, dynamic> data;
  final String? mermaid;
  final String? diagramUrl;
  final bool redirectToArchitect;

  const AgentResponse({
    required this.type,
    required this.assistantText,
    required this.data,
    this.mermaid,
    this.diagramUrl,
    this.redirectToArchitect = false,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> j) => AgentResponse(
    type:                j['type']               as String? ?? 'chat',
    assistantText:       j['assistantText']       as String? ?? '',
    data:                (j['data'] as Map?)?.cast<String, dynamic>() ?? {},
    mermaid:             j['mermaid']             as String?,
    diagramUrl:          j['diagramUrl']          as String?,
    redirectToArchitect: j['redirectToArchitect'] as bool? ?? false,
  );
}

class BedrockException implements Exception {
  final String message;
  const BedrockException(this.message);
  @override String toString() => message;
}


// BedrockService — talks to cogniops_agent Lambda

class BedrockService {
  static String _sessionId = _newSessionId();
  static String _newSessionId() => 'cogniops-${DateTime.now().millisecondsSinceEpoch}';
  static void resetSession()              { _sessionId = _newSessionId(); }
  static void setSessionId(String id)     { _sessionId = id; }

  final _auth = AuthService();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.idToken != null) 'Authorization': _auth.idToken!,
  };

  //  Core POST 
  Future<AgentResponse> _post(String message, String mode) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.chatUrl),
        headers: _headers,
        body: jsonEncode({
          'sessionId': _sessionId,
          'mode':      mode,
          'message':   message,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final raw = response.body.trim();
        final cleaned = _stripFences(raw);

        Map<String, dynamic> parsed;
        try {
          parsed = jsonDecode(cleaned) as Map<String, dynamic>;
        } catch (_) {
          // If top-level parse fails, wrap as plain chat
          return AgentResponse(
            type: 'chat', assistantText: _stripFences(raw),
            data: {},
          );
        }

        
        final at = parsed['assistantText'];
        if (at is String) {
          final stripped = _stripFences(at);
          if (stripped.startsWith('{')) {
            try {
              final inner = jsonDecode(stripped) as Map<String, dynamic>;
              // Merge inner into parsed
              parsed = {...parsed, ...inner};
            } catch (_) {}
          }
        }

        return AgentResponse.fromJson(parsed);
      }

      if (response.statusCode == 504) {
        throw BedrockException('Request timed out (504) — the response took too long. Please try again with a shorter description.');
      }
      if (response.statusCode == 503) {
        throw BedrockException('Service temporarily unavailable (503) — please try again in a moment.');
      }
      throw BedrockException('Server error ${response.statusCode}');
    } on BedrockException { rethrow; }
    catch (e) {
      throw BedrockException('Connection error: $e');
    }
  }

  
  static String _stripFences(String s) {
    var t = s.trim();
    
    if (t.startsWith('```')) {
      t = t.replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: false), '');
      t = t.replaceAll(RegExp(r'```$'), '');
      t = t.trim();
    }
    
    if (t.toLowerCase().startsWith('json\n')) {
      t = t.substring(t.indexOf('\n') + 1).trim();
    }
    return t;
  }

  static String _lastUserMsg(List<Map<String, String>> history) {
    for (final m in history.reversed) {
      if (m['role'] == 'user') return m['content'] ?? '';
    }
    return '';
  }

  
  Future<(String, String, String, String?, bool)> studentChat(List<Map<String, String>> history) async {
    final userMsg = _lastUserMsg(history);
    final r       = await _post(userMsg, 'student');
    final type    = r.type;
    return (_formatForChat(r), type, userMsg, r.mermaid, r.redirectToArchitect);
  }

  Future<(String, String, String, String?, bool)> developerChat(List<Map<String, String>> history) async {
    final userMsg = _lastUserMsg(history);
    final r       = await _post(userMsg, 'dev');
    final type    = r.type;
    return (_formatForChat(r), type, userMsg, r.mermaid, r.redirectToArchitect);
  }

 
  Future<String> quickAsk(String question) async {
    final r = await _post(question, 'student');
    return _formatForChat(r);
  }

  
  String _formatForChat(AgentResponse r) {
    var text = r.assistantText.trim();

    
    if (text.startsWith('{') || text.trimLeft().startsWith('{')) {
      try {
        final inner   = jsonDecode(text.trim()) as Map<String, dynamic>;
        
        if (inner.containsKey('type') || inner.containsKey('assistantText') || inner.containsKey('data')) {
          final cleaned = AgentResponse.fromJson(inner);
          return _formatForChat(cleaned);
        }
      } catch (_) {}
    }

    
    text = text.replaceAll(RegExp(r'"type"\s*:\s*"[^"]*",?\n?'), '');
    text = text.replaceAll(RegExp(r'"assistantText"\s*:\s*"'), '');
    text = text.replaceAll(RegExp(r'"data"\s*:\s*\{[^}]*\},?\n?'), '');
    text = text.replaceAll(RegExp(r'"mermaid"\s*:\s*(null|"[^"]*"),?\n?'), '');
    text = text.replaceAll(RegExp(r'^\s*[\{\}]\s*$', multiLine: true), '');
    text = text.trim();

    switch (r.type) {
      case 'concept':
        final buf = StringBuffer();
        
        List sections = r.data['sections'] as List? ?? [];
        String displayText = text;
        
        if (sections.isEmpty && text.contains('"sections"')) {
          try {
            final cleaned = _stripFences(text);
            final j = jsonDecode(cleaned) as Map<String, dynamic>;
            sections = j['sections'] as List? ?? [];
            displayText = j['assistantText'] as String? ?? j['overview'] as String? ?? '';
          } catch (_) {}
        }
        
        if (displayText.isNotEmpty && !displayText.trim().startsWith('{')) {
          buf.writeln(displayText);
          buf.writeln();
        }
        for (final s in sections) {
          final m = s as Map<String, dynamic>;
          buf.writeln('### ${m['title'] ?? ''}');
          for (final p in (m['points'] as List? ?? [])) buf.writeln('- $p');
          buf.writeln();
        }
        final r1 = buf.toString().trim();
        return r1.isNotEmpty ? r1 : (displayText.isNotEmpty ? displayText : text);

      case 'roadmap':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        
        final items = (r.data['weeks'] as List?) ??
                      (r.data['stages'] as List?) ?? [];
        for (final w in items) {
          final m = w as Map<String, dynamic>;
          final label = m['week'] ?? m['stage'] ?? '';
          final title = m['title'] ?? m['name'] ?? '';
          buf.writeln('### ${label.toString().isNotEmpty ? "Week $label" : ""} ${title.isNotEmpty ? "— $title" : ""}');
          
          final topics = (m['topics'] as List?) ??
                         (m['skills'] as List?) ??
                         (m['content'] as List?) ?? [];
          for (final t in topics) buf.writeln('- $t');
          if (m['estimatedTime'] != null) buf.writeln('  *${m['estimatedTime']}*');
          buf.writeln();
        }
        final r2 = buf.toString().trim();
        return r2.isNotEmpty ? r2 : text;

      case 'quiz':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        final qs = r.data['questions'] as List? ?? [];
        for (int i = 0; i < qs.length; i++) {
          final m = qs[i] as Map<String, dynamic>;
          buf.writeln('**Q${i+1}: ${m['q'] ?? m['question'] ?? ''}**');
          final opts = (m['options'] ?? m['opts']) as List? ?? [];
          for (int j = 0; j < opts.length; j++) {
            final optText = opts[j].toString().replaceFirst(RegExp(r'^[A-D][\.\)\s]+'), '');
            buf.writeln('${String.fromCharCode(65+j)}. $optText');
          }
          buf.writeln();
        }
        final r3 = buf.toString().trim();
        return r3.isNotEmpty ? r3 : text;

      case 'flashcards':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        for (final c in (r.data['cards'] as List? ?? [])) {
          final m = c as Map<String, dynamic>;
          buf.writeln('**${m['front'] ?? ''}**');
          buf.writeln('→ ${m['back'] ?? ''}');
          buf.writeln();
        }
        final r4 = buf.toString().trim();
        return r4.isNotEmpty ? r4 : text;

      case 'terraform':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        final notes = r.data['notes'] as List? ?? [];
        if (notes.isNotEmpty) {
          buf.writeln('**Key points:**');
          for (final n in notes) buf.writeln('- $n');
        }
        final r5 = buf.toString().trim();
        return r5.isNotEmpty ? r5 : text;

      case 'debug':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        final questions = r.data['questions'] as List? ?? [];
        if (questions.isNotEmpty) {
          buf.writeln('**🔍 Diagnostic Questions:**');
          for (final q in questions) buf.writeln('- $q');
          buf.writeln();
        }
        final causes = r.data['likelyCauses'] as List? ?? [];
        if (causes.isNotEmpty) {
          buf.writeln('**⚠️ Likely Causes:**');
          for (final c in causes) buf.writeln('- $c');
          buf.writeln();
        }
        final steps = r.data['fixSteps'] as List? ?? [];
        if (steps.isNotEmpty) {
          buf.writeln('**✅ Fix Steps:**');
          for (int i = 0; i < steps.length; i++) buf.writeln('${i+1}. ${steps[i]}');
        }
        final r6 = buf.toString().trim();
        return r6.isNotEmpty ? r6 : text;

      case 'cost':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        final rawEst = r.data['estimateMonthlyUSD'];
        if (rawEst != null) {
          final estNum = rawEst is num ? rawEst : (double.tryParse(rawEst.toString()) ?? 0);
          buf.writeln('**💰 Est. Monthly Cost: \$${estNum.toStringAsFixed(2)}/mo**\n');
        }
        for (final b in (r.data['breakdown'] as List? ?? [])) buf.writeln('- $b');
        final alts = r.data['cheaperAlternatives'] as List? ?? [];
        if (alts.isNotEmpty) {
          buf.writeln('\n**💡 Cheaper Alternatives:**');
          for (final a in alts) buf.writeln('- $a');
        }
        final r7 = buf.toString().trim();
        return r7.isNotEmpty ? r7 : text;

      case 'backend_suggest':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        final svcs = r.data['suggestedServices'] as List? ?? [];
        if (svcs.isNotEmpty) {
          buf.writeln('**🏗 Recommended AWS Services:**');
          for (final s in svcs) {
            final name = s is Map ? (s['name'] ?? s['service'] ?? s.toString()) : s.toString();
            final desc = s is Map ? (s['purpose'] ?? s['description'] ?? '') : '';
            buf.writeln(desc.isNotEmpty ? '- **$name** — $desc' : '- $name');
          }
          buf.writeln();
        }
        final eps = r.data['apiEndpoints'] as List? ?? [];
        if (eps.isNotEmpty) {
          buf.writeln('**🔌 API Endpoints:**');
          for (final e in eps) buf.writeln('- $e');
        }
        final r8 = buf.toString().trim();
        return r8.isNotEmpty ? r8 : text;

      case 'architecture':
        final buf = StringBuffer();
        if (text.isNotEmpty) { buf.writeln(text); buf.writeln(); }
        final services = (r.data['services'] as List? ?? []);
        if (services.isNotEmpty) {
          buf.writeln('**AWS Services:**');
          for (final s in services) buf.writeln('- $s');
        }
        final result = buf.toString().trim();
        return result.isNotEmpty ? result : 'Architecture generated successfully.';

      default: 
        final trimmed = text.trim();
        if (trimmed.startsWith('{')) {
          try {
            final j = jsonDecode(trimmed) as Map<String, dynamic>;
            final innerType = j['type'] as String?;
            if (innerType != null && innerType != 'chat') {
              return _formatForChat(AgentResponse.fromJson(j));
            }
            return (j['assistantText'] as String? ?? trimmed).trim();
          } catch (_) {}
        }
        
        if (trimmed.contains('"type"') && trimmed.contains('"assistantText"')) {
          try {
            final j = jsonDecode(trimmed) as Map<String, dynamic>;
            return (j['assistantText'] as String? ?? trimmed).trim();
          } catch (_) {
            final cleaned = trimmed
                .replaceAll(RegExp(r'"type"\s*:\s*"[^"]*",??'), '')
                .replaceAll(RegExp(r'"assistantText"\s*:\s*"'), '')
                .replaceAll(RegExp(r'"\s*,?\s*?\s*"data".*', dotAll: true), '')
                .trim()
                .replaceAll(RegExp(r'^["\{]|["\}]$'), '')
                .trim();
            if (cleaned.isNotEmpty) return cleaned;
          }
        }
        return text.isNotEmpty ? text : '...';
    }
  }

  //  Roadmap 
  Future<String> generateRoadmap(String goal) async {
    final r = await _post(
      'Create a detailed $goal learning roadmap. Return as JSON with weeks array. Each week must have: week (number), title (string), topics (array of strings), done (false).',
      'student',
    );

    
    List<Map<String, dynamic>> normalizeWeeks(List raw) {
      return raw.asMap().entries.map((e) {
        final i = e.key;
        final m = e.value as Map<String, dynamic>;
        return {
          'week':   m['week'] ?? m['stage'] ?? m['number'] ?? (i + 1),
          'title':  m['title'] ?? m['name'] ?? m['topic'] ?? 'Week ${i+1}',
          'topics': (m['topics'] ?? m['skills'] ?? m['content'] ?? m['tasks'] ?? []) as List,
          'done':   false,
        };
      }).toList();
    }

    
    if ((r.data['weeks'] as List?)?.isNotEmpty == true) {
      final weeks = normalizeWeeks(r.data['weeks'] as List);
      return jsonEncode({
        'title': r.data['title'] ?? r.data['goal'] ?? goal,
        'goal':  goal,
        'weeks': weeks,
      });
    }

    
    if ((r.data['stages'] as List?)?.isNotEmpty == true) {
      final weeks = normalizeWeeks(r.data['stages'] as List);
      return jsonEncode({
        'title': r.data['title'] ?? r.data['goal'] ?? goal,
        'goal':  goal,
        'weeks': weeks,
      });

    }

    
    try {
      final cleaned = _stripFences(r.assistantText);
      final j = jsonDecode(cleaned) as Map<String, dynamic>;
      final rawList = (j['weeks'] ?? j['stages'] ?? j['roadmap'] ?? []) as List;
      if (rawList.isNotEmpty) {
        return jsonEncode({
          'title': j['title'] ?? j['goal'] ?? goal,
          'goal':  goal,
          'weeks': normalizeWeeks(rawList),
        });
      }
    } catch (_) {}

    
    final lines = r.assistantText.split('\n');
    final weeks = <Map<String, dynamic>>[];
    Map<String, dynamic>? current;
    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final weekMatch = RegExp(r'(?:week|stage|module)\s*(\d+)', caseSensitive: false).firstMatch(l);
      if (weekMatch != null) {
        if (current != null) weeks.add(current);
        current = {
          'week':   int.tryParse(weekMatch.group(1) ?? '') ?? weeks.length + 1,
          'title':  l.replaceAll(RegExp(r'(?:week|stage|module)\s*\d+\s*[:\-—]?\s*', caseSensitive: false), '').trim(),
          'topics': <String>[],
          'done':   false,
        };
      } else if (current != null && (l.startsWith('-') || l.startsWith('•') || l.startsWith('*'))) {
        (current['topics'] as List).add(l.replaceAll(RegExp(r'^[-•*]\s*'), ''));
      }
    }
    if (current != null) weeks.add(current);

    if (weeks.isNotEmpty) {
      return jsonEncode({'title': goal, 'goal': goal, 'weeks': weeks});
    }

    // Complete fallback — create a 4-week template
    return jsonEncode({
      'title': goal,
      'goal': goal,
      'weeks': [
        {'week': 1, 'title': 'Foundations', 'topics': ['Core concepts', 'Setup environment', 'Basic exercises'], 'done': false},
        {'week': 2, 'title': 'Core Skills', 'topics': ['Key tools', 'Hands-on practice', 'Mini project'], 'done': false},
        {'week': 3, 'title': 'Advanced Topics', 'topics': ['Advanced features', 'Real use cases', 'Best practices'], 'done': false},
        {'week': 4, 'title': 'Capstone', 'topics': ['Full project', 'Review & refine', 'Deploy & share'], 'done': false},
      ],
    });
  }

  // Quiz 
  Future<String> generateQuiz({
    required String topic,
    required String difficulty,
    required int count,
  }) async {
    final r = await _post(
      'Generate a $difficulty quiz with $count questions about $topic',
      'student',
    );
    final questions = r.data['questions'] as List?;
    if (questions != null && questions.isNotEmpty) {
      return jsonEncode(questions.map((q) {
        final m    = q as Map<String, dynamic>;
        final ans  = m['answerIndex'] ?? m['ans'] ?? 0;
        final rawOpts = (m['options'] ?? m['opts']) as List? ?? [];
        final opts = rawOpts.map((o) {
          final s = o.toString();
          return RegExp(r'^[A-D][\.\)]\s*').hasMatch(s)
              ? s.replaceFirst(RegExp(r'^[A-D][\.\)]\s*'), '')
              : s;
        }).toList();
        return {
          'q':    m['q'] ?? m['question'] ?? '',
          'opts': opts,
          'ans':  ans is int ? ans : (int.tryParse(ans.toString()) ?? 0),
          'explanation': m['explain'] ?? m['explanation'] ?? '',
        };
      }).toList());
    }
    return jsonEncode([]);
  }

  //  Architecture 
  Future<String> generateArchitecture(String description) async {
    final r = await _post(
      'Design the AWS architecture and diagram for: $description', 'dev',
    );

    String summary = r.assistantText.trim();
    String? mermaid = r.mermaid;

    if (mermaid == null || mermaid.isEmpty) {
      final mm = RegExp(r'(?:PART\s*2.*?:|```mermaid)(.*?)(?:PART\s*3|```|$)',
          dotAll: true, caseSensitive: false).firstMatch(summary);
      if (mm != null) mermaid = mm.group(1)?.trim();
    }

   
    summary = summary
        .replaceAll(RegExp(r'PART\s*1\s*\(TEXT\)\s*:', caseSensitive: false), '')
        .replaceAll(RegExp(r'PART\s*2\s*\(MERMAID\)\s*:.*',
            caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'```mermaid.*?```', dotAll: true), '')
        .replaceAll(RegExp(r'```.*?```', dotAll: true), '')
        .trim();

    if (mermaid != null) {
      mermaid = mermaid.replaceAll(RegExp(r'```mermaid|```'), '').trim();
    }

    String? diagramUrl;
    if (mermaid != null && mermaid.isNotEmpty) {
      diagramUrl = 'https://mermaid.ink/img/${base64Url.encode(utf8.encode(mermaid))}';
    }

    return jsonEncode({
      ...r.data,
      'assistantText':       summary,
      'architectureSummary': summary,
      'mermaid':             mermaid,
      'diagramUrl':          r.diagramUrl ?? diagramUrl,
    });
  }

  //  Terraform
  Future<String> generateTerraform(String description) async {
    final r = await _post('Generate production-ready Terraform HCL for: $description', 'dev');

    String hcl   = '';
    List   notes = [];

    String extractHcl(String raw) {
      final stripped = _stripFences(raw.trim());
      if (stripped.startsWith('{')) {
        try {
          final j = jsonDecode(stripped) as Map<String, dynamic>;
          final inner = j['terraform'] ?? j['hcl'] ?? j['data']?['terraform'];
          if (inner is String && inner.isNotEmpty) return extractHcl(inner);
          
          final d = j['data'] as Map?;
          if (d != null) {
            final dt = d['terraform'] ?? d['hcl'];
            if (dt is String && dt.isNotEmpty) return extractHcl(dt);
          }
        } catch (_) {}
      }
      return stripped
          .replaceAll(RegExp(r'```hcl|```terraform|```'), '')
          .replaceAll(r'', '')
          .replaceAll(r'"', '"')
          .replaceAll(r'\', '\\')
          .trim();
    }

   
    if (r.data.containsKey('terraform')) {
      final raw = r.data['terraform'] as String? ?? '';
      hcl   = extractHcl(raw);
      notes = r.data['notes'] as List? ?? [];
    }
    
    
    if (hcl.isEmpty || hcl.startsWith('{')) {
      hcl = extractHcl(r.assistantText);
      if (notes.isEmpty) {
        try {
          final j = jsonDecode(_stripFences(r.assistantText)) as Map<String, dynamic>;
          notes = (j['notes'] ?? j['data']?['notes'] ?? []) as List;
        } catch (_) {}
      }
    }

    return jsonEncode({'terraform': hcl, 'notes': notes, 'assistantText': r.assistantText});
  }

  //  Backend designer
  Future<String> designBackend(String code) async {
    final r = await _post(
      'Analyze this code and suggest AWS backend services based on this code: $code', 'dev',
    );
    if (r.data.containsKey('suggestedServices')) return jsonEncode(r.data);
    if (r.data.isNotEmpty) return jsonEncode(r.data);
    return jsonEncode({'suggestedServices': [], 'apiEndpoints': [], 'db': [], 'notes': [r.assistantText]});
  }

  //  Cost estimator 
  Future<String> estimateCost(String description) async {
    final r = await _post('Estimate monthly AWS cost for: $description', 'dev');

    
    Map<String, dynamic> extractCostData(Map<String, dynamic> src) {
      Map<String, dynamic> result = Map<String, dynamic>.from(src);
      final nested = src['data'] as Map?;
      if (nested != null) {
        for (final k in ['estimateMonthlyUSD', 'breakdown', 'cheaperAlternatives', 'assumptions', 'services']) {
          if (!result.containsKey(k) && nested.containsKey(k)) {
            result[k] = nested[k];
          }
        }
      }
      return result;
    }

    Map<String, dynamic> data = {};

    
    if (r.data.isNotEmpty) {
      data = extractCostData(r.data);
    }

    
    if (data['estimateMonthlyUSD'] == null) {
      try {
        final cleaned = _stripFences(r.assistantText);
        if (cleaned.startsWith('{')) {
          final j = jsonDecode(cleaned) as Map<String, dynamic>;
          final extracted = extractCostData(j);
          if (extracted['estimateMonthlyUSD'] != null) data = extracted;
        }
      } catch (_) {}
    }

   
    final rawEst = data['estimateMonthlyUSD'];
    data['estimateMonthlyUSD'] = rawEst is num
        ? rawEst.toDouble()
        : double.tryParse(rawEst?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '') ?? 0.0;

    
    final breakdown = data['breakdown'];
    if (breakdown is List) {
      data['breakdown'] = breakdown.map((b) {
        if (b is Map) {
          final svc  = b['service'] ?? b['name'] ?? b['item'] ?? '';
          final cost = b['cost'] ?? b['monthlyCost'] ?? b['estimatedCost'] ?? b['amount'] ?? '';
          final desc = b['description'] ?? b['details'] ?? b['notes'] ?? '';
          if (svc.isNotEmpty && cost.toString().isNotEmpty) {
            return desc.isNotEmpty ? '$svc: \$$cost — $desc' : '$svc: \$$cost';
          }
        }
        final s = b.toString();
        return s.trim().startsWith('{') ? '' : s; 
      }).where((s) => s.isNotEmpty).toList();
    } else {
      data['breakdown'] = <String>[];
    }

    
    for (final key in ['cheaperAlternatives', 'assumptions']) {
      final list = data[key];
      if (list is List) {
        data[key] = list.map((e) => e is Map ? e.toString() : e.toString()).toList();
      } else {
        data[key] = <String>[];
      }
    }

    
    if ((data['assistantText'] as String?)?.isEmpty != false) {
      data['assistantText'] = r.assistantText;
    }

    return jsonEncode(data);
  }

  // Socratic debug
  Future<String> socratiDebug({
    required String errorDescription,
    required List<Map<String, String>> conversationHistory,
  }) async {
  final msg = conversationHistory.isEmpty
        ? 'Debug this error: $errorDescription'
        : errorDescription; 
    final r = await _post(msg, 'dev');
    return _formatForChat(r);
  }

  // Concept explainer
  Future<String> explainConcept(String topic) async {
    final r = await _post('Explain what is $topic', 'student');
    return _formatForChat(r);
  }

  // Flashcard generator
  Future<String> generateFlashcards(String topic) async {
    final r = await _post('Generate flashcards for: $topic', 'student');
    if (r.data.isNotEmpty) return jsonEncode({'data': r.data, 'type': 'flashcards'});
    return jsonEncode({'data': {'cards': []}, 'assistantText': r.assistantText});
  }

  Future<AgentResponse> getFullResponse({
    required String message,
    required bool isDeveloper,
  }) async {
    return _post(message, isDeveloper ? 'dev' : 'student');
  }
}