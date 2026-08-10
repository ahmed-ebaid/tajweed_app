import 'dart:async';
import 'dart:io';

import 'package:app_attest/app_attest.dart';
import 'package:dio/dio.dart';
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

class QuranAttestationService {
  static final Map<String, QuranAttestationService> _instances = {};

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
  final AppAttestClient appAttest;
  final AttestationKeyStore keyStore;
  final bool Function() isIOS;
  final Dio _dio;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  Future<String>? _pendingToken;

  QuranAttestationService({
    required this.workerOrigin,
    required this.appAttest,
    required this.keyStore,
    bool Function()? isIOS,
    Dio? client,
  }) : isIOS = isIOS ?? (() => Platform.isIOS),
       _dio =
           client ??
           Dio(
             BaseOptions(
               baseUrl: workerOrigin,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               contentType: Headers.jsonContentType,
             ),
           );

  String get _keyStoreKey =>
      'qf_app_attest_key_${Uri.parse(workerOrigin).host}';

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
    if (!isIOS() || !await appAttest.isSupported()) {
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
      invalidateAccessToken();
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

  Future<String> _exchangeAssertionForToken(String keyId) async {
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

    _accessToken = token;
    _accessTokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    return token;
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
