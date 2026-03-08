class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://gnpy7lwb2d.execute-api.us-east-1.amazonaws.com/dev',
  );


  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');
  static bool get isNotEmpty => apiKey.isNotEmpty;

  static String get chatUrl     => '$baseUrl/chat';
  static String get healthUrl   => '$baseUrl/health';
  static String get sessionsUrl => '$baseUrl/sessions';
  static String get messagesUrl => '$baseUrl/messages';
  static String get progressUrl => '$baseUrl/progress';
  static String get profileUrl  => '$baseUrl/profile';
  static String get roadmapUrl  => '$baseUrl/roadmap';
  static String get quizUrl     => '$baseUrl/quiz-results';

  static bool get isConfigured =>
      baseUrl.isNotEmpty && baseUrl.startsWith('https://');
}