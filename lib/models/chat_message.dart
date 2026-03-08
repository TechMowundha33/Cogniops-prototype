class ChatMessage {
  final String id;
  final String role;       // 'user' | 'ai'
  final String text;
  final DateTime timestamp;
  final String? messageType;       // 'concept' | 'quiz' | 'roadmap' | 'architecture' etc.
  final String? topic;             // original topic for flashcard generation
  final String? mermaid;           // mermaid diagram code for architecture
  final bool redirectToArchitect;  // dev mode — open architect screen

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.messageType,
    this.topic,
    this.mermaid,
    this.redirectToArchitect = false,
  });

  bool get isUser         => role == 'user';
  bool get isAi           => role == 'ai';
  bool get isConcept      => messageType == 'concept';
  bool get isArchitecture => messageType == 'architecture';

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}




