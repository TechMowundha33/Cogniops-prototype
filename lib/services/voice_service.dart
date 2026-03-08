import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';

class VoiceService {
  static final VoiceService _i = VoiceService._();
  factory VoiceService() => _i;
  VoiceService._();

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (ApiConfig.apiKey.isNotEmpty) 'x-api-key': ApiConfig.apiKey,
  };

  
  Future<TranscribeResult> transcribe({
    required Uint8List audioBytes,
    String mime = 'audio/webm',
    String? languageCode, 
  }) async {
    if (!ApiConfig.isConfigured) {
      throw const VoiceException('API URL not configured in api_config.dart');
    }

    const url = '${ApiConfig.baseUrl}/voice/transcribe';
    final b64 = base64Encode(audioBytes);

    http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({
          'audioB64': b64,
          'mime': mime,
          if (languageCode != null) 'languageCode': languageCode,
        }),
      ).timeout(const Duration(seconds: 60));
    } on Exception catch (e) {
      throw VoiceException('Network error: $e');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw VoiceException('Transcribe: unexpected response (${resp.statusCode})');
    }

    if (resp.statusCode == 200) {
      return TranscribeResult(
        text:       (data['text'] as String?) ?? '',
        language:   (data['language'] as String?) ?? 'en-IN',
        confidence: (data['confidence'] as num?)?.toDouble(),
      );
    }
    throw VoiceException(
      data['error'] as String? ?? 'Transcription failed (${resp.statusCode})',
    );
  }

  //  TTS

  /// Convert text → Amazon Polly → returns MP3 bytes.
  Future<Uint8List> synthesize({
    required String text,
    String voice = 'Joanna',
    String languageCode = 'en-IN',
  }) async {
    if (!ApiConfig.isConfigured) {
      throw const VoiceException('API URL not configured in api_config.dart');
    }

    const url = '${ApiConfig.baseUrl}/voice/tts';

    http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({
          'text': text.length > 3000 ? text.substring(0, 3000) : text,
          'voice': voice,
          'languageCode': languageCode,
        }),
      ).timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw VoiceException('Network error: $e');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw VoiceException('TTS: unexpected response (${resp.statusCode})');
    }

    if (resp.statusCode == 200) {
      final b64 = data['audioB64'] as String? ?? '';
      if (b64.isEmpty) throw const VoiceException('TTS returned empty audio');
      return base64Decode(b64);
    }
    throw VoiceException(
      data['error'] as String? ?? 'TTS failed (${resp.statusCode})',
    );
  }
}

// Models 

class TranscribeResult {
  final String text;
  final String language;
  final double? confidence;
  const TranscribeResult({
    required this.text,
    required this.language,
    this.confidence,
  });
}

class VoiceException implements Exception {
  final String message;
  const VoiceException(this.message);
  @override
  String toString() => 'VoiceException: $message';
}