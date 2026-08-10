import 'dart:convert';

import 'package:app_attest/app_attest.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/quran_attestation_service.dart';

class _MemoryKeyStore implements AttestationKeyStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeAppAttestClient implements AppAttestClient {
  static final keyId = '${List.filled(43, 'A').join()}=';

  bool supported = true;
  int generatedKeys = 0;
  int attestations = 0;
  int assertions = 0;

  @override
  Future<AppAttestAttestation> attestKey({
    required String keyId,
    required String challenge,
  }) async {
    attestations++;
    return AppAttestAttestation(
      keyId: keyId,
      attestationObject: base64Encode(utf8.encode('attestation')),
    );
  }

  @override
  Future<AppAttestAssertion> generateAssertion({
    required String keyId,
    required String challenge,
  }) async {
    assertions++;
    return AppAttestAssertion(
      keyId: keyId,
      assertionObject: base64Encode(utf8.encode('assertion')),
    );
  }

  @override
  Future<String> generateKey() async {
    generatedKeys++;
    return keyId;
  }

  @override
  Future<bool> isSupported() async => supported;
}

class _AttestationAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = options.data as Map<String, dynamic>?;
    final body = switch (options.path) {
      '/v1/attest/challenge' => {
        'challenge': data?['purpose'] == 'register'
            ? 'register-challenge'
            : 'assert-challenge',
        'expires_in': 300,
      },
      '/v1/attest/register' => {'status': 'registered'},
      '/v1/attest/token' => {
        'access_token': 'attested-access-token',
        'token_type': 'Bearer',
        'expires_in': 600,
      },
      _ => <String, Object>{'error': 'not found'},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      options.path == '/v1/attest/register' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAppAttestClient appAttest;
  late _MemoryKeyStore keyStore;
  late _AttestationAdapter adapter;
  late QuranAttestationService service;

  setUp(() {
    appAttest = _FakeAppAttestClient();
    keyStore = _MemoryKeyStore();
    adapter = _AttestationAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://worker.example'))
      ..httpClientAdapter = adapter;
    service = QuranAttestationService(
      workerOrigin: 'https://worker.example',
      appAttest: appAttest,
      keyStore: keyStore,
      isIOS: () => true,
      client: dio,
    );
  });

  test('registers a new App Attest key and exchanges an assertion', () async {
    final token = await service.accessToken();

    expect(token, 'attested-access-token');
    expect(appAttest.generatedKeys, 1);
    expect(appAttest.attestations, 1);
    expect(appAttest.assertions, 1);
    expect(adapter.requests.map((request) => request.path), [
      '/v1/attest/challenge',
      '/v1/attest/register',
      '/v1/attest/challenge',
      '/v1/attest/token',
    ]);
  });

  test('coalesces concurrent token requests and caches the result', () async {
    final tokens = await Future.wait([
      service.accessToken(),
      service.accessToken(),
    ]);
    final cached = await service.accessToken();

    expect(tokens, everyElement('attested-access-token'));
    expect(cached, 'attested-access-token');
    expect(appAttest.generatedKeys, 1);
    expect(appAttest.assertions, 1);
  });

  test('fails closed when App Attest is unsupported', () async {
    appAttest.supported = false;

    await expectLater(
      service.accessToken(),
      throwsA(isA<QuranAttestationException>()),
    );
    expect(adapter.requests, isEmpty);
  });
}
