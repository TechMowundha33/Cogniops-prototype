import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import 'package:cogniops/providers/auth_service.dart';


// ApiService — all Lambda API calls with real auth headers


class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _auth = AuthService();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.idToken != null) 'Authorization': _auth.idToken!,
  };

  String get _userId => _auth.cognitoUser?.sub ?? 'demo-user';

  //  Profile 
  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.profileUrl}?userId=$_userId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<void> saveProfile({
    required String name,
    required String email,
    required String role,
  }) async {
    await http.post(
      Uri.parse(ApiConfig.profileUrl),
      headers: _headers,
      body: jsonEncode({'userId': _userId, 'name': name, 'email': email, 'role': role}),
    ).timeout(const Duration(seconds: 15));
  }

  //  Progress
  Future<Map<String, dynamic>> getProgress() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.progressUrl}?userId=$_userId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<void> addXP(int xpDelta, {int modulesDelta = 0}) async {
    await http.post(
      Uri.parse(ApiConfig.progressUrl),
      headers: _headers,
      body: jsonEncode({
        'userId': _userId,
        'xpDelta': xpDelta,
        'modulesCompletedDelta': modulesDelta,
      }),
    ).timeout(const Duration(seconds: 15));
  }

  //  Quiz Results 
  Future<void> saveQuizResult({
    required String topic,
    required String difficulty,
    required int score,
    required int total,
    required int xpEarned,
  }) async {
    await http.post(
      Uri.parse(ApiConfig.quizUrl),
      headers: _headers,
      body: jsonEncode({
        'userId': _userId,
        'topic': topic,
        'difficulty': difficulty,
        'score': score,
        'total': total,
        'xpEarned': xpEarned,
      }),
    ).timeout(const Duration(seconds: 15));
  }

  Future<List<Map<String, dynamic>>> getQuizResults({int limit = 10}) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.quizUrl}?userId=$_userId&limit=$limit'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    final data = _parse(res);
    return (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  //  Roadmap (multi-roadmap support via roadmapId)
  // Primary roadmap (backwards compatible)
  Future<Map<String, dynamic>?> getRoadmap() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.roadmapUrl}?userId=$_userId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    final data = _parse(res);
    return data['roadmap'] as Map<String, dynamic>?;
  }

  // Get all roadmaps — stored as a JSON list in the 'allRoadmaps' field
  Future<List<Map<String, dynamic>>> getAllRoadmaps() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.roadmapUrl}?userId=$_userId&all=true'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      final data = _parse(res);
      // Try 'roadmaps' list first, fall back to wrapping single 'roadmap'
      final list = data['roadmaps'] as List?;
      if (list != null) return list.cast<Map<String, dynamic>>();
      final single = data['roadmap'] as Map<String, dynamic>?;
      if (single != null) return [single];
      return [];
    } catch (_) { return []; }
  }

  Future<void> saveRoadmap({
    required String goal,
    required String title,
    required List<Map<String, dynamic>> weeks,
    String? roadmapId,
  }) async {
    await http.post(
      Uri.parse(ApiConfig.roadmapUrl),
      headers: _headers,
      body: jsonEncode({
        'userId': _userId,
        'goal': goal,
        'title': title,
        'weeks': weeks,
        if (roadmapId != null) 'roadmapId': roadmapId,
      }),
    ).timeout(const Duration(seconds: 15));
  }

  Future<void> markWeekDone(int weekIndex, bool done, {String? roadmapId}) async {
    await http.put(
      Uri.parse(ApiConfig.roadmapUrl),
      headers: _headers,
      body: jsonEncode({
        'userId': _userId,
        'weekIndex': weekIndex,
        'done': done,
        if (roadmapId != null) 'roadmapId': roadmapId,
      }),
    ).timeout(const Duration(seconds: 15));
  }

  Future<void> deleteRoadmap(String roadmapId) async {
    try {
      await http.delete(
        Uri.parse('${ApiConfig.roadmapUrl}?userId=$_userId&roadmapId=$roadmapId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  // Sessions 
  Future<List<Map<String, dynamic>>> getSessions() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.sessionsUrl}?userId=$_userId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    final data = _parse(res);
    return (data['sessions'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<String> createSession(String title) async {
    final res = await http.post(
      Uri.parse(ApiConfig.sessionsUrl),
      headers: _headers,
      body: jsonEncode({'userId': _userId, 'title': title}),
    ).timeout(const Duration(seconds: 15));
    final data = _parse(res);
    return data['sessionId'] as String;
  }

  Future<List<Map<String, dynamic>>> getMessages(String sessionId, {int limit = 50}) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.messagesUrl}?sessionId=$sessionId&limit=$limit'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    final data = _parse(res);
    return (data['messages'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Save a single message to DynamoDB (called after user sends + after AI replies)
  Future<void> saveMessage({
    required String sessionId,
    required String role, // 'user' or 'assistant'
    required String content,
  }) async {
    try {
      await http.post(
        Uri.parse(ApiConfig.messagesUrl),
        headers: _headers,
        body: jsonEncode({
          'sessionId': sessionId,
          'userId':    _userId,
          'role':      role,
          'content':   content,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Silent fail — don't block UI if save fails
    }
  }

  // Parse helper
  Map<String, dynamic> _parse(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}