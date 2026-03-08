import 'dart:convert';
import 'package:http/http.dart' as http;

const _kRegion   = 'us-east-1';
const _kClientId = 'cb750orb7ves7b1se38pgbfoo';
const _kEndpoint = 'https://cognito-idp.$_kRegion.amazonaws.com/';

class AuthException implements Exception {
  final String message;
  final bool needsVerification;
  const AuthException(this.message, {this.needsVerification = false});
  @override String toString() => message;
}

class CognitoTokens {
  final String idToken, accessToken, refreshToken;
  final int expiresIn;
  const CognitoTokens({required this.idToken, required this.accessToken,
      required this.refreshToken, required this.expiresIn});
}

class CognitoUser {
  final String sub, email, name, role;
  const CognitoUser({required this.sub, required this.email,
      required this.name, required this.role});
}

class AuthService {
  static final AuthService _i = AuthService._();
  factory AuthService() => _i;
  AuthService._();

  CognitoTokens? _tokens;
  CognitoUser?   _cognitoUser;

  String?      get idToken     => _tokens?.idToken;
  String?      get accessToken => _tokens?.accessToken;
  CognitoUser? get cognitoUser => _cognitoUser;
  bool         get isLoggedIn  => _tokens != null;

  Future<void> signUp({required String email, required String password,
      required String name, required String role}) async {
    final res = await _post('SignUp', {
      'ClientId': _kClientId, 'Username': email, 'Password': password,
      'UserAttributes': [
        {'Name': 'email', 'Value': email},
        {'Name': 'name',  'Value': name},
        {'Name': 'custom:role', 'Value': role},
      ],
    });
    _checkError(res);
  }

  Future<void> confirmSignUp({required String email, required String code}) async {
    final res = await _post('ConfirmSignUp', {
      'ClientId': _kClientId, 'Username': email, 'ConfirmationCode': code,
    });
    _checkError(res);
  }

  Future<void> resendCode(String email) async {
    await _post('ResendConfirmationCode', {'ClientId': _kClientId, 'Username': email});
  }

  Future<CognitoUser> signIn({required String email, required String password}) async {
    final res = await _post('InitiateAuth', {
      'AuthFlow': 'USER_PASSWORD_AUTH', 'ClientId': _kClientId,
      'AuthParameters': {'USERNAME': email, 'PASSWORD': password},
    });
    if (res['__type'] != null) {
      if (res['__type'] == 'UserNotConfirmedException') {
        throw const AuthException('Please verify your email first.', needsVerification: true);
      }
      _checkError(res);
    }
    final r = res['AuthenticationResult'] as Map<String, dynamic>;
    _tokens = CognitoTokens(
      idToken: r['IdToken'] as String, accessToken: r['AccessToken'] as String,
      refreshToken: r['RefreshToken'] as String, expiresIn: r['ExpiresIn'] as int? ?? 3600,
    );
    _cognitoUser = _decodeIdToken(_tokens!.idToken, email);
    return _cognitoUser!;
  }

  Future<void> signOut() async {
    if (_tokens?.accessToken != null) {
      try { await _post('GlobalSignOut', {'AccessToken': _tokens!.accessToken}); } catch (_) {}
    }
    _tokens = null; _cognitoUser = null;
  }

  Future<void> refresh() async {
    if (_tokens?.refreshToken == null) return;
    final res = await _post('InitiateAuth', {
      'AuthFlow': 'REFRESH_TOKEN_AUTH', 'ClientId': _kClientId,
      'AuthParameters': {'REFRESH_TOKEN': _tokens!.refreshToken},
    });
    if (res['AuthenticationResult'] != null) {
      final r = res['AuthenticationResult'] as Map<String, dynamic>;
      _tokens = CognitoTokens(
        idToken: r['IdToken'] as String, accessToken: r['AccessToken'] as String,
        refreshToken: _tokens!.refreshToken, expiresIn: r['ExpiresIn'] as int? ?? 3600,
      );
      _cognitoUser = _decodeIdToken(_tokens!.idToken, _cognitoUser?.email ?? '');
    }
  }

  Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse(_kEndpoint),
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.$action',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _checkError(Map<String, dynamic> res) {
    if (res['__type'] == null) return;
    final type = res['__type'] as String;
    final msg  = res['message'] as String?;
    switch (type) {
      case 'UserNotFoundException':     throw const AuthException('No account with this email.');
      case 'NotAuthorizedException':    throw const AuthException('Incorrect email or password.');
      case 'UsernameExistsException':   throw const AuthException('An account already exists with this email.');
      case 'InvalidPasswordException':  throw const AuthException('Password needs 8+ chars, uppercase, number & symbol.');
      case 'CodeMismatchException':     throw const AuthException('Wrong verification code.');
      case 'ExpiredCodeException':      throw const AuthException('Code expired — request a new one.');
      case 'LimitExceededException':    throw const AuthException('Too many attempts. Please wait.');
      default:                          throw AuthException(msg ?? 'Something went wrong.');
    }
  }

  CognitoUser _decodeIdToken(String token, String fallbackEmail) {
    try {
      final parts  = token.split('.');
      final padded = parts[1] + '=' * ((4 - parts[1].length % 4) % 4);
      final claims = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      return CognitoUser(
        sub:   claims['sub']         as String? ?? '',
        email: claims['email']       as String? ?? fallbackEmail,
        name:  claims['name']        as String? ?? fallbackEmail.split('@').first,
        role:  claims['custom:role'] as String? ?? 'student',
      );
    } catch (_) {
      return CognitoUser(sub: '', email: fallbackEmail,
          name: fallbackEmail.split('@').first, role: 'student');
    }
  }
}