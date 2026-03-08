// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';

// class ChatProvider extends ChangeNotifier {
//   final List<ChatMessage> _messages = [];
//   bool _isTyping = false;
//   bool _isDeveloper = false;
//   String? _lastError;

//   List<ChatMessage> get messages => List.unmodifiable(_messages);
//   bool get isTyping => _isTyping;
//   String? get lastError => _lastError;

//   void initStudent() {
//     _isDeveloper = false;
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: '1',
//       role: 'ai',
//       text: "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: '1',
//       role: 'ai',
//       text: "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable.",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError = null;

//     _messages.add(ChatMessage(
//       id: DateTime.now().millisecondsSinceEpoch.toString(),
//       role: 'user',
//       text: text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       // Build conversation history for Bedrock (user/assistant alternating)
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.role == 'user') {
//           history.add({'role': 'user', 'content': m.text});
//         } else {
//           history.add({'role': 'assistant', 'content': m.text});
//         }
//       }

//       final reply = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role: 'ai',
//         text: reply,
//         timestamp: DateTime.now(),
//       ));
//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role: 'ai',
//         text: '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _lastError = e.toString();
//       _messages.add(ChatMessage(
//         id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role: 'ai',
//         text: '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
//   }

//   void clear() {
//     _messages.clear();
//     _lastError = null;
//     notifyListeners();
//   }
// }





//  UPDATED


//  UPDATED



// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';
// import '../services/api_service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatSession — represents one conversation thread
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatSession {
//   final String id;
//   final String title;
//   final DateTime updatedAt;
//   const ChatSession({required this.id, required this.title, required this.updatedAt});

//   factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
//     id:        m['sessionId'] as String,
//     title:     m['title']    as String? ?? 'New chat',
//     updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
//   );

//   String get timeLabel {
//     final diff = DateTime.now().difference(updatedAt);
//     if (diff.inDays == 0) return 'Today';
//     if (diff.inDays == 1) return 'Yesterday';
//     if (diff.inDays < 7)  return '${diff.inDays} days ago';
//     return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatProvider — manages sessions + messages
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatProvider extends ChangeNotifier {
//   final _api = ApiService();

//   // ── State ──────────────────────────────────────────────────────────────────
//   final List<ChatMessage>  _messages  = [];
//   final List<ChatSession>  _sessions  = [];
//   String?   _activeSessionId;
//   bool      _isTyping       = false;
//   bool      _isDeveloper    = false;
//   bool      _loadingSessions= false;
//   bool      _loadingHistory = false;
//   String?   _lastError;

//   // ── Getters ────────────────────────────────────────────────────────────────
//   List<ChatMessage> get messages        => List.unmodifiable(_messages);
//   List<ChatSession> get sessions        => List.unmodifiable(_sessions);
//   String?           get activeSessionId => _activeSessionId;
//   bool              get isTyping        => _isTyping;
//   bool              get loadingSessions => _loadingSessions;
//   bool              get loadingHistory  => _loadingHistory;
//   String?           get lastError       => _lastError;
//   bool              get hasSessions     => _sessions.isNotEmpty;

//   // ── Init ───────────────────────────────────────────────────────────────────
//   void initStudent() {
//     _isDeveloper = false;
//     if (_messages.isEmpty) _addWelcome(false);
//     loadSessions();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     if (_messages.isEmpty) _addWelcome(true);
//     loadSessions();
//   }

//   void _addWelcome(bool isDev) {
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: 'welcome',
//       role: 'ai',
//       text: isDev
//           ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
//           : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   // ── Load all sessions from DynamoDB ───────────────────────────────────────
//   Future<void> loadSessions() async {
//     _loadingSessions = true;
//     notifyListeners();
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//     } catch (_) {}
//     _loadingSessions = false;
//     notifyListeners();
//   }

//   // ── Start a brand new chat ─────────────────────────────────────────────────
//   Future<void> newChat() async {
//     _activeSessionId = null;
//     _messages.clear();
//     _addWelcome(_isDeveloper);
//     BedrockService.resetSession();
//     notifyListeners();
//   }

//   // ── Load a past session ────────────────────────────────────────────────────
//   Future<void> loadSession(String sessionId) async {
//     if (_activeSessionId == sessionId) return;
//     _activeSessionId = sessionId;
//     _messages.clear();
//     _loadingHistory = true;
//     notifyListeners();

//     try {
//       final msgs = await _api.getMessages(sessionId);
//       _messages.clear();
//       for (final m in msgs) {
//         final role    = m['role'] as String? ?? 'user';
//         final content = m['content'] as String? ?? '';
//         if (content.isEmpty) continue;
//         _messages.add(ChatMessage(
//           id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
//           role:      role == 'assistant' ? 'ai' : role,
//           text:      content,
//           timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
//         ));
//       }
//       if (_messages.isEmpty) _addWelcome(_isDeveloper);
//     } catch (_) {
//       _addWelcome(_isDeveloper);
//     }

//     _loadingHistory = false;
//     notifyListeners();
//   }

//   // ── Send a message ─────────────────────────────────────────────────────────
//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError  = null;

//     // Create session on first real message
//     if (_activeSessionId == null) {
//       try {
//         final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
//         _activeSessionId = await _api.createSession(title);
//         BedrockService.setSessionId(_activeSessionId!);
//       } catch (_) {
//         _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
//         BedrockService.setSessionId(_activeSessionId!);
//       }
//     }

//     _messages.add(ChatMessage(
//       id:        DateTime.now().millisecondsSinceEpoch.toString(),
//       role:      'user',
//       text:      text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.id == 'welcome') continue;
//         history.add({
//           'role':    m.role == 'ai' ? 'assistant' : 'user',
//           'content': m.text,
//         });
//       }

//       final reply = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      reply,
//         timestamp: DateTime.now(),
//       ));

//       // ── Persist both messages to DynamoDB ────────────────────────
//       if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
//       }

//       // Refresh sessions list to show updated title
//       _refreshSessionsQuietly();

//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
//   }

//   // ── Quietly refresh sessions without showing loading spinner ──────────────
//   Future<void> _refreshSessionsQuietly() async {
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//       notifyListeners();
//     } catch (_) {}
//   }

//   // ── Delete a session ───────────────────────────────────────────────────────
//   void deleteSessionLocally(String sessionId) {
//     _sessions.removeWhere((s) => s.id == sessionId);
//     if (_activeSessionId == sessionId) {
//       _activeSessionId = null;
//       _messages.clear();
//       _addWelcome(_isDeveloper);
//     }
//     notifyListeners();
//   }

//   void clear() {
//     _messages.clear();
//     _sessions.clear();
//     _activeSessionId = null;
//     _lastError       = null;
//     notifyListeners();
//   }
// }






//  Updated 2

//  Updated 2




// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';
// import '../services/api_service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatSession — represents one conversation thread
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatSession {
//   final String id;
//   final String title;
//   final DateTime updatedAt;
//   const ChatSession({required this.id, required this.title, required this.updatedAt});

//   factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
//     id:        m['sessionId'] as String,
//     title:     m['title']    as String? ?? 'New chat',
//     updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
//   );

//   String get timeLabel {
//     final diff = DateTime.now().difference(updatedAt);
//     if (diff.inDays == 0) return 'Today';
//     if (diff.inDays == 1) return 'Yesterday';
//     if (diff.inDays < 7)  return '${diff.inDays} days ago';
//     return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatProvider — manages sessions + messages
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatProvider extends ChangeNotifier {
//   final _api = ApiService();

//   // ── State ──────────────────────────────────────────────────────────────────
//   final List<ChatMessage>  _messages  = [];
//   final List<ChatSession>  _sessions  = [];
//   String?   _activeSessionId;
//   bool      _isTyping       = false;
//   bool      _isDeveloper    = false;
//   bool      _loadingSessions= false;
//   bool      _loadingHistory = false;
//   String?   _lastError;

//   // ── Getters ────────────────────────────────────────────────────────────────
//   List<ChatMessage> get messages        => List.unmodifiable(_messages);
//   List<ChatSession> get sessions        => List.unmodifiable(_sessions);
//   String?           get activeSessionId => _activeSessionId;
//   bool              get isTyping        => _isTyping;
//   bool              get loadingSessions => _loadingSessions;
//   bool              get loadingHistory  => _loadingHistory;
//   String?           get lastError       => _lastError;
//   bool              get hasSessions     => _sessions.isNotEmpty;

//   // ── Init ───────────────────────────────────────────────────────────────────
//   void initStudent() {
//     _isDeveloper = false;
//     if (_messages.isEmpty) _addWelcome(false);
//     loadSessions();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     if (_messages.isEmpty) _addWelcome(true);
//     loadSessions();
//   }

//   void _addWelcome(bool isDev) {
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: 'welcome',
//       role: 'ai',
//       text: isDev
//           ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
//           : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   // ── Load all sessions from DynamoDB ───────────────────────────────────────
//   Future<void> loadSessions() async {
//     _loadingSessions = true;
//     notifyListeners();
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//     } catch (_) {}
//     _loadingSessions = false;
//     notifyListeners();
//   }

//   // ── Start a brand new chat ─────────────────────────────────────────────────
//   Future<void> newChat() async {
//     _activeSessionId = null;
//     _messages.clear();
//     _addWelcome(_isDeveloper);
//     BedrockService.resetSession();
//     notifyListeners();
//   }

//   // ── Load a past session ────────────────────────────────────────────────────
//   Future<void> loadSession(String sessionId) async {
//     if (_activeSessionId == sessionId) return;
//     _activeSessionId = sessionId;
//     _messages.clear();
//     _loadingHistory = true;
//     notifyListeners();

//     try {
//       final msgs = await _api.getMessages(sessionId);
//       _messages.clear();
//       for (final m in msgs) {
//         final role    = m['role'] as String? ?? 'user';
//         final content = m['content'] as String? ?? '';
//         if (content.isEmpty) continue;
//         _messages.add(ChatMessage(
//           id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
//           role:      role == 'assistant' ? 'ai' : role,
//           text:      content,
//           timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
//         ));
//       }
//       if (_messages.isEmpty) _addWelcome(_isDeveloper);
//     } catch (_) {
//       _addWelcome(_isDeveloper);
//     }

//     _loadingHistory = false;
//     notifyListeners();
//   }

//   // ── Send a message ─────────────────────────────────────────────────────────
//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError  = null;

//     // Create session on first real message
//     if (_activeSessionId == null) {
//       try {
//         final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
//         _activeSessionId = await _api.createSession(title);
//         BedrockService.setSessionId(_activeSessionId!);
//       } catch (_) {
//         _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
//         BedrockService.setSessionId(_activeSessionId!);
//       }
//     }

//     _messages.add(ChatMessage(
//       id:        DateTime.now().millisecondsSinceEpoch.toString(),
//       role:      'user',
//       text:      text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.id == 'welcome') continue;
//         history.add({
//           'role':    m.role == 'ai' ? 'assistant' : 'user',
//           'content': m.text,
//         });
//       }

//       final reply = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      reply,
//         timestamp: DateTime.now(),
//       ));

//       // ── Persist both messages to DynamoDB ────────────────────────
//       if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
//       }

//       // Refresh sessions list to show updated title
//       _refreshSessionsQuietly();

//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
//   }

//   // ── Quietly refresh sessions without showing loading spinner ──────────────
//   Future<void> _refreshSessionsQuietly() async {
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//       notifyListeners();
//     } catch (_) {}
//   }

//   // ── Delete a session ───────────────────────────────────────────────────────
//   void deleteSessionLocally(String sessionId) {
//     _sessions.removeWhere((s) => s.id == sessionId);
//     if (_activeSessionId == sessionId) {
//       _activeSessionId = null;
//       _messages.clear();
//       _addWelcome(_isDeveloper);
//     }
//     notifyListeners();
//   }

//   void clear() {
//     _messages.clear();
//     _sessions.clear();
//     _activeSessionId = null;
//     _lastError       = null;
//     notifyListeners();
//   }
// }






//  Updated 3

//  Updated 3



// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';
// import '../services/api_service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatSession — represents one conversation thread
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatSession {
//   final String id;
//   final String title;
//   final DateTime updatedAt;
//   const ChatSession({required this.id, required this.title, required this.updatedAt});

//   factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
//     id:        m['sessionId'] as String,
//     title:     m['title']    as String? ?? 'New chat',
//     updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
//   );

//   String get timeLabel {
//     final diff = DateTime.now().difference(updatedAt);
//     if (diff.inDays == 0) return 'Today';
//     if (diff.inDays == 1) return 'Yesterday';
//     if (diff.inDays < 7)  return '${diff.inDays} days ago';
//     return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatProvider — manages sessions + messages
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatProvider extends ChangeNotifier {
//   final _api = ApiService();

//   // ── State ──────────────────────────────────────────────────────────────────
//   final List<ChatMessage>  _messages  = [];
//   final List<ChatSession>  _sessions  = [];
//   String?   _activeSessionId;
//   bool      _isTyping       = false;
//   bool      _isDeveloper    = false;
//   bool      _loadingSessions= false;
//   bool      _loadingHistory = false;
//   String?   _lastError;

//   // ── Getters ────────────────────────────────────────────────────────────────
//   List<ChatMessage> get messages        => List.unmodifiable(_messages);
//   List<ChatSession> get sessions        => List.unmodifiable(_sessions);
//   String?           get activeSessionId => _activeSessionId;
//   bool              get isTyping        => _isTyping;
//   bool              get loadingSessions => _loadingSessions;
//   bool              get loadingHistory  => _loadingHistory;
//   String?           get lastError       => _lastError;
//   bool              get hasSessions     => _sessions.isNotEmpty;

//   // ── Init ───────────────────────────────────────────────────────────────────
//   void initStudent() {
//     _isDeveloper = false;
//     if (_messages.isEmpty) _addWelcome(false);
//     loadSessions();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     if (_messages.isEmpty) _addWelcome(true);
//     loadSessions();
//   }

//   void _addWelcome(bool isDev) {
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: 'welcome',
//       role: 'ai',
//       text: isDev
//           ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
//           : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   // ── Load all sessions from DynamoDB ───────────────────────────────────────
//   Future<void> loadSessions() async {
//     _loadingSessions = true;
//     notifyListeners();
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//     } catch (_) {}
//     _loadingSessions = false;
//     notifyListeners();
//   }

//   // ── Start a brand new chat ─────────────────────────────────────────────────
//   Future<void> newChat() async {
//     _activeSessionId = null;
//     _messages.clear();
//     _addWelcome(_isDeveloper);
//     BedrockService.resetSession();
//     notifyListeners();
//   }

//   // ── Load a past session ────────────────────────────────────────────────────
//   Future<void> loadSession(String sessionId) async {
//     if (_activeSessionId == sessionId) return;
//     _activeSessionId = sessionId;
//     _messages.clear();
//     _loadingHistory = true;
//     notifyListeners();

//     try {
//       final msgs = await _api.getMessages(sessionId);
//       _messages.clear();
//       for (final m in msgs) {
//         final role    = m['role'] as String? ?? 'user';
//         final content = m['content'] as String? ?? '';
//         if (content.isEmpty) continue;
//         _messages.add(ChatMessage(
//           id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
//           role:      role == 'assistant' ? 'ai' : role,
//           text:      content,
//           timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
//         ));
//       }
//       if (_messages.isEmpty) _addWelcome(_isDeveloper);
//     } catch (_) {
//       _addWelcome(_isDeveloper);
//     }

//     _loadingHistory = false;
//     notifyListeners();
//   }

//   // ── Send a message ─────────────────────────────────────────────────────────
//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError  = null;

//     // Create session on first real message
//     if (_activeSessionId == null) {
//       try {
//         final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
//         _activeSessionId = await _api.createSession(title);
//         BedrockService.setSessionId(_activeSessionId!);
//       } catch (_) {
//         _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
//         BedrockService.setSessionId(_activeSessionId!);
//       }
//     }

//     _messages.add(ChatMessage(
//       id:        DateTime.now().millisecondsSinceEpoch.toString(),
//       role:      'user',
//       text:      text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.id == 'welcome') continue;
//         history.add({
//           'role':    m.role == 'ai' ? 'assistant' : 'user',
//           'content': m.text,
//         });
//       }

//       final (reply, msgType, topic) = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id:          (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:        'ai',
//         text:        reply,
//         timestamp:   DateTime.now(),
//         messageType: msgType,
//         topic:       topic,
//       ));

//       // ── Persist both messages to DynamoDB ────────────────────────
//       if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
//       }

//       // Refresh sessions list to show updated title
//       _refreshSessionsQuietly();

//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
//   }

//   // ── Quietly refresh sessions without showing loading spinner ──────────────
//   Future<void> _refreshSessionsQuietly() async {
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//       notifyListeners();
//     } catch (_) {}
//   }

//   // ── Delete a session ───────────────────────────────────────────────────────
//   void deleteSessionLocally(String sessionId) {
//     _sessions.removeWhere((s) => s.id == sessionId);
//     if (_activeSessionId == sessionId) {
//       _activeSessionId = null;
//       _messages.clear();
//       _addWelcome(_isDeveloper);
//     }
//     notifyListeners();
//   }

//   void clear() {
//     _messages.clear();
//     _sessions.clear();
//     _activeSessionId = null;
//     _lastError       = null;
//     notifyListeners();
//   }
// }







//  Updated 4



//  Updated 4  might be final



// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';
// import '../services/api_service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatSession — represents one conversation thread
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatSession {
//   final String id;
//   final String title;
//   final DateTime updatedAt;
//   const ChatSession({required this.id, required this.title, required this.updatedAt});

//   factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
//     id:        m['sessionId'] as String,
//     title:     m['title']    as String? ?? 'New chat',
//     updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
//   );

//   String get timeLabel {
//     final diff = DateTime.now().difference(updatedAt);
//     if (diff.inDays == 0) return 'Today';
//     if (diff.inDays == 1) return 'Yesterday';
//     if (diff.inDays < 7)  return '${diff.inDays} days ago';
//     return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatProvider — manages sessions + messages
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatProvider extends ChangeNotifier {
//   final _api = ApiService();

//   // ── State ──────────────────────────────────────────────────────────────────
//   final List<ChatMessage>  _messages  = [];
//   final List<ChatSession>  _sessions  = [];
//   String?   _activeSessionId;
//   bool      _isTyping       = false;
//   bool      _isDeveloper    = false;
//   bool      _loadingSessions= false;
//   bool      _loadingHistory = false;
//   String?   _lastError;

//   // ── Getters ────────────────────────────────────────────────────────────────
//   List<ChatMessage> get messages        => List.unmodifiable(_messages);
//   List<ChatSession> get sessions        => List.unmodifiable(_sessions);
//   String?           get activeSessionId => _activeSessionId;
//   bool              get isTyping        => _isTyping;
//   bool              get loadingSessions => _loadingSessions;
//   bool              get loadingHistory  => _loadingHistory;
//   String?           get lastError       => _lastError;
//   bool              get hasSessions     => _sessions.isNotEmpty;

//   // ── Init ───────────────────────────────────────────────────────────────────
//   void initStudent() {
//     _isDeveloper = false;
//     if (_messages.isEmpty) _addWelcome(false);
//     loadSessions();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     if (_messages.isEmpty) _addWelcome(true);
//     loadSessions();
//   }

//   void _addWelcome(bool isDev) {
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: 'welcome',
//       role: 'ai',
//       text: isDev
//           ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
//           : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   // ── Load all sessions from DynamoDB ───────────────────────────────────────
//   Future<void> loadSessions() async {
//     _loadingSessions = true;
//     notifyListeners();
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//     } catch (_) {}
//     _loadingSessions = false;
//     notifyListeners();
//   }

//   // ── Start a brand new chat ─────────────────────────────────────────────────
//   Future<void> newChat() async {
//     _activeSessionId = null;
//     _messages.clear();
//     _addWelcome(_isDeveloper);
//     BedrockService.resetSession();
//     notifyListeners();
//   }

//   // ── Load a past session ────────────────────────────────────────────────────
//   Future<void> loadSession(String sessionId) async {
//     if (_activeSessionId == sessionId) return;
//     _activeSessionId = sessionId;
//     _messages.clear();
//     _loadingHistory = true;
//     notifyListeners();

//     try {
//       final msgs = await _api.getMessages(sessionId);
//       _messages.clear();
//       for (final m in msgs) {
//         final role    = m['role'] as String? ?? 'user';
//         final content = m['content'] as String? ?? '';
//         if (content.isEmpty) continue;
//         _messages.add(ChatMessage(
//           id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
//           role:      role == 'assistant' ? 'ai' : role,
//           text:      content,
//           timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
//         ));
//       }
//       if (_messages.isEmpty) _addWelcome(_isDeveloper);
//     } catch (_) {
//       _addWelcome(_isDeveloper);
//     }

//     _loadingHistory = false;
//     notifyListeners();
//   }

//   // ── Send a message ─────────────────────────────────────────────────────────
//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError  = null;

//     // Create session on first real message
//     if (_activeSessionId == null) {
//       try {
//         final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
//         _activeSessionId = await _api.createSession(title);
//         BedrockService.setSessionId(_activeSessionId!);
//       } catch (_) {
//         _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
//         BedrockService.setSessionId(_activeSessionId!);
//       }
//     }

//     _messages.add(ChatMessage(
//       id:        DateTime.now().millisecondsSinceEpoch.toString(),
//       role:      'user',
//       text:      text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.id == 'welcome') continue;
//         history.add({
//           'role':    m.role == 'ai' ? 'assistant' : 'user',
//           'content': m.text,
//         });
//       }

//       final (reply, msgType, topic, mermaid, redirect) = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id:                  (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:                'ai',
//         text:                reply,
//         timestamp:           DateTime.now(),
//         messageType:         msgType,
//         topic:               topic,
//         mermaid:             mermaid,
//         redirectToArchitect: redirect,
//       ));

//       // ── Persist both messages to DynamoDB ────────────────────────
//       if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
//       }

//       // Refresh sessions list to show updated title
//       _refreshSessionsQuietly();

//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
// }

//   // ── Quietly refresh sessions without showing loading spinner ──────────────
//   Future<void> _refreshSessionsQuietly() async {
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//       notifyListeners();
//     } catch (_) {}
//   }

//   // ── Delete a session ───────────────────────────────────────────────────────
//   void deleteSessionLocally(String sessionId) {
//     _sessions.removeWhere((s) => s.id == sessionId);
//     if (_activeSessionId == sessionId) {
//       _activeSessionId = null;
//       _messages.clear();
//       _addWelcome(_isDeveloper);
//     }
//     notifyListeners();
//   }

//   void clear() {
//     _messages.clear();
//     _sessions.clear();
//     _activeSessionId = null;
//     _lastError       = null;
//     notifyListeners();
//   }
// }






//  updated 5

//  updated 5

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';
// import '../services/api_service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatSession — represents one conversation thread
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatSession {
//   final String id;
//   final String title;
//   final DateTime updatedAt;
//   const ChatSession({required this.id, required this.title, required this.updatedAt});

//   factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
//     id:        m['sessionId'] as String,
//     title:     m['title']    as String? ?? 'New chat',
//     updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
//   );

//   String get timeLabel {
//     final diff = DateTime.now().difference(updatedAt);
//     if (diff.inDays == 0) return 'Today';
//     if (diff.inDays == 1) return 'Yesterday';
//     if (diff.inDays < 7)  return '${diff.inDays} days ago';
//     return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatProvider — manages sessions + messages
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatProvider extends ChangeNotifier {
//   final _api = ApiService();

//   // ── State ──────────────────────────────────────────────────────────────────
//   final List<ChatMessage>  _messages  = [];
//   final List<ChatSession>  _sessions  = [];
//   String?   _activeSessionId;
//   bool      _isTyping       = false;
//   bool      _isDeveloper    = false;
//   bool      _loadingSessions= false;
//   bool      _loadingHistory = false;
//   String?   _lastError;

//   // ── Getters ────────────────────────────────────────────────────────────────
//   List<ChatMessage> get messages        => List.unmodifiable(_messages);
//   List<ChatSession> get sessions        => List.unmodifiable(_sessions);
//   String?           get activeSessionId => _activeSessionId;
//   bool              get isTyping        => _isTyping;
//   bool              get loadingSessions => _loadingSessions;
//   bool              get loadingHistory  => _loadingHistory;
//   String?           get lastError       => _lastError;
//   bool              get hasSessions     => _sessions.isNotEmpty;

//   // ── Init ───────────────────────────────────────────────────────────────────
//   void initStudent() {
//     _isDeveloper = false;
//     if (_messages.isEmpty) _addWelcome(false);
//     loadSessions();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     if (_messages.isEmpty) _addWelcome(true);
//     loadSessions();
//   }

//   void _addWelcome(bool isDev) {
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: 'welcome',
//       role: 'ai',
//       text: isDev
//           ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
//           : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   // ── Load all sessions from DynamoDB ───────────────────────────────────────
//   Future<void> loadSessions() async {
//     _loadingSessions = true;
//     notifyListeners();
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//     } catch (_) {}
//     _loadingSessions = false;
//     notifyListeners();
//   }

//   // ── Start a brand new chat ─────────────────────────────────────────────────
//   Future<void> newChat() async {
//     _activeSessionId = null;
//     _messages.clear();
//     _addWelcome(_isDeveloper);
//     BedrockService.resetSession();
//     notifyListeners();
//   }

//   // ── Load a past session ────────────────────────────────────────────────────
//   Future<void> loadSession(String sessionId) async {
//     if (_activeSessionId == sessionId) return;
//     _activeSessionId = sessionId;
//     _messages.clear();
//     _loadingHistory = true;
//     notifyListeners();

//     try {
//       final msgs = await _api.getMessages(sessionId);
//       _messages.clear();
//       for (final m in msgs) {
//         final role    = m['role'] as String? ?? 'user';
//         final content = m['content'] as String? ?? '';
//         if (content.isEmpty) continue;
//         _messages.add(ChatMessage(
//           id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
//           role:      role == 'assistant' ? 'ai' : role,
//           text:      content,
//           timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
//         ));
//       }
//       if (_messages.isEmpty) _addWelcome(_isDeveloper);
//     } catch (_) {
//       _addWelcome(_isDeveloper);
//     }

//     _loadingHistory = false;
//     notifyListeners();
//   }

//   // ── Send a message ─────────────────────────────────────────────────────────
//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError  = null;

//     // Create session on first real message
//     if (_activeSessionId == null) {
//       try {
//         final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
//         _activeSessionId = await _api.createSession(title);
//         BedrockService.setSessionId(_activeSessionId!);
//       } catch (_) {
//         _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
//         BedrockService.setSessionId(_activeSessionId!);
//       }
//     }

//     _messages.add(ChatMessage(
//       id:        DateTime.now().millisecondsSinceEpoch.toString(),
//       role:      'user',
//       text:      text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.id == 'welcome') continue;
//         history.add({
//           'role':    m.role == 'ai' ? 'assistant' : 'user',
//           'content': m.text,
//         });
//       }

//       final (reply, msgType, topic, mermaid, redirect) = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id:                  (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:                'ai',
//         text:                reply,
//         timestamp:           DateTime.now(),
//         messageType:         msgType,
//         topic:               topic,
//         mermaid:             mermaid,
//         redirectToArchitect: redirect,
//       ));

//       // ── Persist both messages to DynamoDB ────────────────────────
//       if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
//         _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
//       }

//       // Refresh sessions list to show updated title
//       _refreshSessionsQuietly();

//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
//   }

//   // ── Quietly refresh sessions without showing loading spinner ──────────────
//   Future<void> _refreshSessionsQuietly() async {
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//       notifyListeners();
//     } catch (_) {}
//   }

//   // ── Delete a session ───────────────────────────────────────────────────────
//   void deleteSessionLocally(String sessionId) {
//     _sessions.removeWhere((s) => s.id == sessionId);
//     if (_activeSessionId == sessionId) {
//       _activeSessionId = null;
//       _messages.clear();
//       _addWelcome(_isDeveloper);
//     }
//     notifyListeners();
//   }

//   void clear() {
//     _messages.clear();
//     _sessions.clear();
//     _activeSessionId = null;
//     _lastError       = null;
//     notifyListeners();
//   }
// }




//  Updated Updated

//  updated

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/bedrock_service.dart';
// import '../services/api_service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatSession — represents one conversation thread
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatSession {
//   final String id;
//   final String title;
//   final DateTime updatedAt;
//   const ChatSession({required this.id, required this.title, required this.updatedAt});

//   factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
//     id:        m['sessionId'] as String,
//     title:     m['title']    as String? ?? 'New chat',
//     updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
//   );

//   String get timeLabel {
//     final diff = DateTime.now().difference(updatedAt);
//     if (diff.inDays == 0) return 'Today';
//     if (diff.inDays == 1) return 'Yesterday';
//     if (diff.inDays < 7)  return '${diff.inDays} days ago';
//     return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ChatProvider — manages sessions + messages
// // ─────────────────────────────────────────────────────────────────────────────
// class ChatProvider extends ChangeNotifier {
//   final _api = ApiService();

//   // ── State ──────────────────────────────────────────────────────────────────
//   final List<ChatMessage>  _messages  = [];
//   final List<ChatSession>  _sessions  = [];
//   String?   _activeSessionId;
//   bool      _isTyping       = false;
//   bool      _isDeveloper    = false;
//   bool      _loadingSessions= false;
//   bool      _loadingHistory = false;
//   String?   _lastError;

//   // ── Getters ────────────────────────────────────────────────────────────────
//   List<ChatMessage> get messages        => List.unmodifiable(_messages);
//   List<ChatSession> get sessions        => List.unmodifiable(_sessions);
//   String?           get activeSessionId => _activeSessionId;
//   bool              get isTyping        => _isTyping;
//   bool              get loadingSessions => _loadingSessions;
//   bool              get loadingHistory  => _loadingHistory;
//   String?           get lastError       => _lastError;
//   bool              get hasSessions     => _sessions.isNotEmpty;

//   // ── Init ───────────────────────────────────────────────────────────────────
//   void initStudent() {
//     _isDeveloper = false;
//     if (_messages.isEmpty) _addWelcome(false);
//     loadSessions();
//   }

//   void initDeveloper() {
//     _isDeveloper = true;
//     if (_messages.isEmpty) _addWelcome(true);
//     loadSessions();
//   }

//   void _addWelcome(bool isDev) {
//     _messages.clear();
//     _messages.add(ChatMessage(
//       id: 'welcome',
//       role: 'ai',
//       text: isDev
//           ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion — powered by Claude on AWS Bedrock.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
//           : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, Azure, GCP, DevOps, or cloud certifications. What would you like to explore today?",
//       timestamp: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   // ── Load all sessions from DynamoDB ───────────────────────────────────────
//   Future<void> loadSessions() async {
//     _loadingSessions = true;
//     notifyListeners();
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//     } catch (_) {}
//     _loadingSessions = false;
//     notifyListeners();
//   }

//   // ── Start a brand new chat ─────────────────────────────────────────────────
//   Future<void> newChat() async {
//     _activeSessionId = null;
//     _messages.clear();
//     _addWelcome(_isDeveloper);
//     BedrockService.resetSession();
//     notifyListeners();
//   }

//   // ── Load a past session ────────────────────────────────────────────────────
//   Future<void> loadSession(String sessionId) async {
//     if (_activeSessionId == sessionId) return;
//     _activeSessionId = sessionId;
//     _messages.clear();
//     _loadingHistory = true;
//     notifyListeners();

//     try {
//       final msgs = await _api.getMessages(sessionId);
//       _messages.clear();
//       for (final m in msgs) {
//         final role    = m['role'] as String? ?? 'user';
//         final content = m['content'] as String? ?? '';
//         if (content.isEmpty) continue;
//         _messages.add(ChatMessage(
//           id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
//           role:      role == 'assistant' ? 'ai' : role,
//           text:      content,
//           timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
//         ));
//       }
//       if (_messages.isEmpty) _addWelcome(_isDeveloper);
//     } catch (_) {
//       _addWelcome(_isDeveloper);
//     }

//     _loadingHistory = false;
//     notifyListeners();
//   }

//   // ── Send a message ─────────────────────────────────────────────────────────
//   Future<void> sendMessage(String text, {bool? isDeveloper}) async {
//     if (text.trim().isEmpty) return;
//     final isdev = isDeveloper ?? _isDeveloper;
//     _lastError  = null;

//     // Create session on first real message
//     if (_activeSessionId == null) {
//       try {
//         final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
//         _activeSessionId = await _api.createSession(title);
//         BedrockService.setSessionId(_activeSessionId!);
//       } catch (_) {
//         _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
//         BedrockService.setSessionId(_activeSessionId!);
//       }
//     }

//     _messages.add(ChatMessage(
//       id:        DateTime.now().millisecondsSinceEpoch.toString(),
//       role:      'user',
//       text:      text,
//       timestamp: DateTime.now(),
//     ));
//     _isTyping = true;
//     notifyListeners();

//     try {
//       final history = <Map<String, String>>[];
//       for (final m in _messages) {
//         if (m.id == 'welcome') continue;
//         history.add({
//           'role':    m.role == 'ai' ? 'assistant' : 'user',
//           'content': m.text,
//         });
//       }

//       final (reply, msgType, topic, mermaid, redirect) = isdev
//           ? await BedrockService().developerChat(history)
//           : await BedrockService().studentChat(history);

//       _messages.add(ChatMessage(
//         id:                  (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:                'ai',
//         text:                reply,
//         timestamp:           DateTime.now(),
//         messageType:         msgType,
//         topic:               topic,
//         mermaid:             mermaid,
//         redirectToArchitect: redirect,
//       ));

//       // ── Persist both messages to DynamoDB (FIXED: added await) ────────────
//       if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
//         await _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
//         await _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
//       }

//       // Refresh sessions list to show updated title
//       _refreshSessionsQuietly();

//     } on BedrockException catch (e) {
//       _lastError = e.message;
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
//         timestamp: DateTime.now(),
//       ));
//     } catch (e) {
//       _messages.add(ChatMessage(
//         id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
//         role:      'ai',
//         text:      '⚠️ Unexpected error: $e',
//         timestamp: DateTime.now(),
//       ));
//     } finally {
//       _isTyping = false;
//       notifyListeners();
//     }
//   }

//   // ── Quietly refresh sessions without showing loading spinner ──────────────
//   Future<void> _refreshSessionsQuietly() async {
//     try {
//       final raw = await _api.getSessions();
//       _sessions.clear();
//       _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
//       notifyListeners();
//     } catch (_) {}
//   }

//   // ── Delete a session ───────────────────────────────────────────────────────
//   void deleteSessionLocally(String sessionId) {
//     _sessions.removeWhere((s) => s.id == sessionId);
//     if (_activeSessionId == sessionId) {
//       _activeSessionId = null;
//       _messages.clear();
//       _addWelcome(_isDeveloper);
//     }
//     notifyListeners();
//   }

//   void clear() {
//     _messages.clear();
//     _sessions.clear();
//     _activeSessionId = null;
//     _lastError       = null;
//     notifyListeners();
//   }
// }







//  UPDATED 2 UPDATED 2



//  UPDATED 2 UPDATED 2


import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/bedrock_service.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatSession — represents one conversation thread
// ─────────────────────────────────────────────────────────────────────────────
class ChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;
  const ChatSession({required this.id, required this.title, required this.updatedAt});

  factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
    id:        m['sessionId'] as String,
    title:     m['title']    as String? ?? 'New chat',
    updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  String get timeLabel {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatProvider — manages sessions + messages
// ─────────────────────────────────────────────────────────────────────────────
class ChatProvider extends ChangeNotifier {
  final _api = ApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  final List<ChatMessage>  _messages  = [];
  final List<ChatSession>  _sessions  = [];
  String?   _activeSessionId;
  bool      _isTyping       = false;
  bool      _isDeveloper    = false;
  bool      _loadingSessions= false;
  bool      _loadingHistory = false;
  String?   _lastError;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<ChatMessage> get messages        => List.unmodifiable(_messages);
  List<ChatSession> get sessions        => List.unmodifiable(_sessions);
  String?           get activeSessionId => _activeSessionId;
  bool              get isTyping        => _isTyping;
  bool              get loadingSessions => _loadingSessions;
  bool              get loadingHistory  => _loadingHistory;
  String?           get lastError       => _lastError;
  bool              get hasSessions     => _sessions.isNotEmpty;

  // ── Init ───────────────────────────────────────────────────────────────────
  void initStudent() {
    _isDeveloper = false;
    if (_messages.isEmpty) _addWelcome(false);
    loadSessions();
  }

  void initDeveloper() {
    _isDeveloper = true;
    if (_messages.isEmpty) _addWelcome(true);
    loadSessions();
  }

  void _addWelcome(bool isDev) {
    _messages.clear();
    _messages.add(ChatMessage(
      id: 'welcome',
      role: 'ai',
      text: isDev
          ? "Welcome, Engineer! 👨‍💻 I'm your AI architect companion.\n\nPaste code, describe your system, or ask me to generate infrastructure. I can help with AWS architecture, Terraform, cost optimization, debugging, and more. Let's build something remarkable."
          : "Hey! I'm CogniBot 🤖 — your AI mentor for cloud mastery. I'm connected to Claude via AWS Bedrock, so my answers are real and up-to-date!\n\nAsk me anything about AWS, DevOps, or cloud certifications. What would you like to explore today?",
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  // ── Load all sessions from DynamoDB ───────────────────────────────────────
  Future<void> loadSessions() async {
    _loadingSessions = true;
    notifyListeners();
    try {
      final raw = await _api.getSessions();
      _sessions.clear();
      _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
    } catch (_) {}
    _loadingSessions = false;
    notifyListeners();
  }

  // ── Start a brand new chat ─────────────────────────────────────────────────
  Future<void> newChat() async {
    _activeSessionId = null;
    _messages.clear();
    _addWelcome(_isDeveloper);
    BedrockService.resetSession();
    notifyListeners();
  }

  // ── Load a past session ────────────────────────────────────────────────────
  Future<void> loadSession(String sessionId) async {
    if (_activeSessionId == sessionId) return;
    _activeSessionId = sessionId;
    _messages.clear();
    _loadingHistory = true;
    notifyListeners();

    try {
      final msgs = await _api.getMessages(sessionId);
      _messages.clear();
      for (final m in msgs) {
        final role    = m['role'] as String? ?? 'user';
        final content = m['content'] as String? ?? '';
        if (content.isEmpty) continue;
        _messages.add(ChatMessage(
          id:        '${m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
          role:      role == 'assistant' ? 'ai' : role,
          text:      content,
          timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        ));
      }
      if (_messages.isEmpty) _addWelcome(_isDeveloper);
    } catch (_) {
      _addWelcome(_isDeveloper);
    }

    _loadingHistory = false;
    notifyListeners();
  }

  // ── Send a message ─────────────────────────────────────────────────────────
  Future<void> sendMessage(String text, {bool? isDeveloper}) async {
    if (text.trim().isEmpty) return;
    final isdev = isDeveloper ?? _isDeveloper;
    _lastError  = null;

    // Create session on first real message
    if (_activeSessionId == null) {
      try {
        final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
        _activeSessionId = await _api.createSession(title);
        BedrockService.setSessionId(_activeSessionId!);
      } catch (_) {
        _activeSessionId = 'local-${DateTime.now().millisecondsSinceEpoch}';
        BedrockService.setSessionId(_activeSessionId!);
      }
    }

    _messages.add(ChatMessage(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      role:      'user',
      text:      text,
      timestamp: DateTime.now(),
    ));
    _isTyping = true;
    notifyListeners();

    try {
      final history = <Map<String, String>>[];
      for (final m in _messages) {
        if (m.id == 'welcome') continue;
        history.add({
          'role':    m.role == 'ai' ? 'assistant' : 'user',
          'content': m.text,
        });
      }

      final (reply, msgType, topic, mermaid, redirect) = isdev
          ? await BedrockService().developerChat(history)
          : await BedrockService().studentChat(history);

      _messages.add(ChatMessage(
        id:                  (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role:                'ai',
        text:                reply,
        timestamp:           DateTime.now(),
        messageType:         msgType,
        topic:               topic,
        mermaid:             mermaid,
        redirectToArchitect: redirect,
      ));

      // ── Persist both messages to DynamoDB (FIXED: added await) ────────────
      if (_activeSessionId != null && !_activeSessionId!.startsWith('local-')) {
        await _api.saveMessage(sessionId: _activeSessionId!, role: 'user',      content: text);
        await _api.saveMessage(sessionId: _activeSessionId!, role: 'assistant', content: reply);
      }

      // Refresh sessions list to show updated title
      _refreshSessionsQuietly();

    } on BedrockException catch (e) {
      _lastError = e.message;
      _messages.add(ChatMessage(
        id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role:      'ai',
        text:      '⚠️ Could not reach AWS Bedrock.\n\n${e.message}',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _messages.add(ChatMessage(
        id:        (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role:      'ai',
        text:      '⚠️ Unexpected error: $e',
        timestamp: DateTime.now(),
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ── Quietly refresh sessions without showing loading spinner ──────────────
  Future<void> _refreshSessionsQuietly() async {
    try {
      final raw = await _api.getSessions();
      _sessions.clear();
      _sessions.addAll(raw.map((m) => ChatSession.fromMap(m)));
      notifyListeners();
    } catch (_) {}
  }

  // ── Delete a session ───────────────────────────────────────────────────────
  void deleteSessionLocally(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
      _messages.clear();
      _addWelcome(_isDeveloper);
    }
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    _sessions.clear();
    _activeSessionId = null;
    _lastError       = null;
    notifyListeners();
  }
}