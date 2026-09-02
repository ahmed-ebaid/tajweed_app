import 'dart:async';
import 'dart:io';

import 'package:app_attest/app_attest.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class QuranAttestationException implements Exception {
  final String message;

  const QuranAttestationException(this.message);

  @override
  String toString() => message;
}

abstract interface class AppAttestClient {
  Future<bool> isSupported();
  Future<String> generateKey();
  Future<AppAttestAttestation> attestKey({
    required String keyId,
    required String challenge,
  });
  Future<AppAttestAssertion> generateAssertion({
    required String keyId,
    required String challenge,
  });
}

class NativeAppAttestClient implements AppAttestClient {
  const NativeAppAttestClient();

  @override
  Future<bool> isSupported() => AppAttest.isSupported();

  @override
  Future<String> generateKey() => AppAttest.generateKey();

  @override
  Future<AppAttestAttestation> attestKey({
    required String keyId,
    required String challenge,
  }) {
    return AppAttest.attestKey(keyId: keyId, challenge: challenge);
  }

  @override
  Future<AppAttestAssertion> generateAssertion({
    required String keyId,
    required String challenge,
  }) {
    return AppAttest.generateAssertion(keyId: keyId, challenge: challenge);
  }
}

abstract interface class AttestationKeyStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class HiveAttestationKeyStore implements AttestationKeyStore {
  Box<dynamic> get _box => Hive.box('settings');

  @override
  String? read(String key) => _box.get(key) as String?;

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}

/// Device platform used to select an [AttestationProvider].
enum AttestationPlatform {
  ios('iOS'),
  android('Android'),
  other('This platform');

  const AttestationPlatform(this.displayName);

  /// Name used in user-facing error messages.
  final String displayName;

  static AttestationPlatform current() {
    if (Platform.isIOS) return AttestationPlatform.ios;
    if (Platform.isAndroid) return AttestationPlatform.android;
    return AttestationPlatform.other;
  }
}

/// A short-lived bearer token issued by the Quran proxy.
class AttestationToken {
  final String value;
  final Duration expiresIn;

  const AttestationToken({required this.value, required this.expiresIn});
}

/// Proves app integrity to the Quran proxy and exchanges that proof for a
/// bearer token.
///
/// Each platform supplies its own implementation so token caching and request
/// coalescing in [QuranAttestationService] stay platform-agnostic. iOS uses
/// Apple App Attest; Android will use the Play Integrity API once it is wired
/// up, which only requires adding a provider here.
abstract interface class AttestationProvider {
  /// Platform name used in user-facing error messages.
  String get platformName;

  /// Runs the full attestation handshake and returns a freshly issued token.
  ///
  /// Throws [QuranAttestationException] when this device cannot attest.
  Future<AttestationToken> obtainToken();
}

/// Apple App Attest provider.
///
/// Registers a hardware-backed key on first use, then exchanges a signed
/// assertion for a token on every refresh.
class AppAttestProvider implements AttestationProvider {
  final String workerOrigin;
  final AppAttestClient appAttest;
  final AttestationKeyStore keyStore;
  final Dio _dio;

  AppAttestProvider({
    required this.workerOrigin,
    required this.appAttest,
    required this.keyStore,
    required Dio client,
  }) : _dio = client;

  @override
  String get platformName => AttestationPlatform.ios.displayName;

  String get _keyStoreKey =>
      'qf_app_attest_key_${Uri.parse(workerOrigin).host}';

  @override
  Future<AttestationToken> obtainToken() async {
    if (!await appAttest.isSupported()) {
      throw const QuranAttestationException(
        'This device does not support Apple App Attest.',
      );
    }

    var keyId = keyStore.read(_keyStoreKey);
    keyId ??= await _registerNewKey();

    try {
      return await _exchangeAssertionForToken(keyId);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401 &&
          error.response?.statusCode != 409) {
        rethrow;
      }
      await keyStore.delete(_keyStoreKey);
      return _exchangeAssertionForToken(await _registerNewKey());
    }
  }

  Future<String> _registerNewKey() async {
    final keyId = await appAttest.generateKey();
    final challenge = await _requestChallenge(keyId, 'register');
    final attestation = await appAttest.attestKey(
      keyId: keyId,
      challenge: challenge,
    );
    if (attestation.keyId != keyId) {
      throw const QuranAttestationException(
        'Apple App Attest returned an unexpected key.',
      );
    }

    await _dio.post<void>(
      '/v1/attest/register',
      data: {
        'key_id': keyId,
        'challenge': challenge,
        'attestation': attestation.attestationObject,
      },
    );
    await keyStore.write(_keyStoreKey, keyId);
    return keyId;
  }

  Future<AttestationToken> _exchangeAssertionForToken(String keyId) async {
    final challenge = await _requestChallenge(keyId, 'assert');
    final assertion = await appAttest.generateAssertion(
      keyId: keyId,
      challenge: challenge,
    );
    if (assertion.keyId != keyId) {
      throw const QuranAttestationException(
        'Apple App Attest returned an unexpected key.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/attest/token',
      data: {
        'key_id': keyId,
        'challenge': challenge,
        'assertion': assertion.assertionObject,
      },
    );
    final data = response.data;
    final token = data?['access_token'];
    final expiresIn = data?['expires_in'];
    if (token is! String ||
        token.isEmpty ||
        expiresIn is! int ||
        expiresIn <= 0) {
      throw const QuranAttestationException(
        'The attestation server returned an invalid access token.',
      );
    }

    return AttestationToken(
      value: token,
      expiresIn: Duration(seconds: expiresIn),
    );
  }

  Future<String> _requestChallenge(String keyId, String purpose) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/attest/challenge',
      data: {'key_id': keyId, 'purpose': purpose},
    );
    final challenge = response.data?['challenge'];
    if (challenge is! String || challenge.isEmpty) {
      throw const QuranAttestationException(
        'The attestation server returned an invalid challenge.',
      );
    }
    return challenge;
  }
}

/// Fails closed on platforms that do not have an attestation provider yet.
///
/// Android lands here until the Play Integrity API is wired up.
class UnsupportedAttestationProvider implements AttestationProvider {
  @override
  final String platformName;

  const UnsupportedAttestationProvider(this.platformName);

  @override
  Future<AttestationToken> obtainToken() async {
    throw QuranAttestationException(
      '$platformName does not have a supported attestation provider yet, so '
      'Quran content cannot be loaded. Debug builds can set '
      'QURAN_BYPASS_APP_ATTEST_IN_DEBUG and QURAN_PROXY_TEST_TOKEN to reach a '
      'non-production worker.',
    );
  }
}

class QuranAttestationService {
  static const _allowBypassInDebug = bool.fromEnvironment(
    'QURAN_BYPASS_APP_ATTEST_IN_DEBUG',
    defaultValue: false,
  );
  static const _proxyTestToken = String.fromEnvironment(
    'QURAN_PROXY_TEST_TOKEN',
  );

  static final Map<String, QuranAttestationService> _instances = {};

  static bool get appAttestBypassEnabled =>
      !kReleaseMode && _allowBypassInDebug;

  static String? get proxyTestToken {
    if (kReleaseMode || !_allowBypassInDebug || _proxyTestToken.isEmpty) {
      return null;
    }
    return _proxyTestToken;
  }

  static QuranAttestationService forContentApi(String contentApiBaseUrl) {
    final origin = Uri.parse(contentApiBaseUrl).origin;
    return _instances.putIfAbsent(
      origin,
      () => QuranAttestationService(
        workerOrigin: origin,
        appAttest: const NativeAppAttestClient(),
        keyStore: HiveAttestationKeyStore(),
      ),
    );
  }

  final String workerOrigin;
  final AttestationProvider provider;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  Future<String>? _pendingToken;

  factory QuranAttestationService({
    required String workerOrigin,
    required AppAttestClient appAttest,
    required AttestationKeyStore keyStore,
    AttestationPlatform Function()? platform,
    AttestationProvider? provider,
    Dio? client,
  }) {
    final dio =
        client ??
        Dio(
          BaseOptions(
            baseUrl: workerOrigin,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            contentType: Headers.jsonContentType,
          ),
        );
    return QuranAttestationService._(
      workerOrigin: workerOrigin,
      provider:
          provider ??
          _providerFor(
            (platform ?? AttestationPlatform.current)(),
            workerOrigin: workerOrigin,
            appAttest: appAttest,
            keyStore: keyStore,
            client: dio,
          ),
    );
  }

  QuranAttestationService._({
    required this.workerOrigin,
    required this.provider,
  });

  static AttestationProvider _providerFor(
    AttestationPlatform platform, {
    required String workerOrigin,
    required AppAttestClient appAttest,
    required AttestationKeyStore keyStore,
    required Dio client,
  }) {
    return switch (platform) {
      AttestationPlatform.ios => AppAttestProvider(
        workerOrigin: workerOrigin,
        appAttest: appAttest,
        keyStore: keyStore,
        client: client,
      ),
      AttestationPlatform.android || AttestationPlatform.other =>
        UnsupportedAttestationProvider(platform.displayName),
    };
  }

  Future<String> accessToken() {
    final token = _accessToken;
    final expiresAt = _accessTokenExpiresAt;
    if (token != null &&
        expiresAt != null &&
        DateTime.now().isBefore(
          expiresAt.subtract(const Duration(seconds: 30)),
        )) {
      return Future.value(token);
    }

    _pendingToken ??= _obtainAccessToken();
    return _pendingToken!.whenComplete(() => _pendingToken = null);
  }

  void invalidateAccessToken() {
    _accessToken = null;
    _accessTokenExpiresAt = null;
  }

  Future<String> _obtainAccessToken() async {
    if (_shouldBypassAttestation()) {
      return '';
    }

    final token = await provider.obtainToken();
    _accessToken = token.value;
    _accessTokenExpiresAt = DateTime.now().add(token.expiresIn);
    return token.value;
  }

  bool _shouldBypassAttestation() {
    if (kReleaseMode) return false;
    return _allowBypassInDebug;
  }
}
