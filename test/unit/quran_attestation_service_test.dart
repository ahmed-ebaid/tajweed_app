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
        'challenge': switch (data?['purpose']) {
          'register' => 'register-challenge',
          'integrity' => 'integrity-challenge',
          _ => 'assert-challenge',
        },
        'expires_in': 300,
      },
      '/v1/attest/register' => {'status': 'registered'},
      '/v1/attest/token' => {
        'access_token': 'attested-access-token',
        'token_type': 'Bearer',
        'expires_in': 600,
      },
      '/v1/attest/play-integrity' => {
        'access_token': 'play-integrity-access-token',
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

class _FakePlayIntegrityClient implements PlayIntegrityClient {
  final List<String> nonces = [];
  int? lastCloudProjectNumber;
  Object? error;

  @override
  Future<String> requestIntegrityToken({
    required String nonce,
    required int cloudProjectNumber,
  }) async {
    nonces.add(nonce);
    lastCloudProjectNumber = cloudProjectNumber;
    final failure = error;
    if (failure != null) throw failure;
    return 'integrity-token-for-$nonce';
  }
}

class _StubProvider implements AttestationProvider {
  @override
  String get platformName => 'Stub';

  @override
  Future<AttestationToken> obtainToken() async => const AttestationToken(
    value: 'stub-token',
    expiresIn: Duration(minutes: 10),
  );
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
      platform: () => AttestationPlatform.ios,
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

  group('provider selection', () {
    QuranAttestationService serviceFor(AttestationPlatform platform) {
      final dio = Dio(BaseOptions(baseUrl: 'https://worker.example'))
        ..httpClientAdapter = adapter;
      return QuranAttestationService(
        workerOrigin: 'https://worker.example',
        appAttest: appAttest,
        keyStore: keyStore,
        platform: () => platform,
        client: dio,
      );
    }

    test('uses App Attest on iOS', () {
      expect(
        serviceFor(AttestationPlatform.ios).provider,
        isA<AppAttestProvider>(),
      );
    });

    test('uses Play Integrity on Android', () {
      expect(
        serviceFor(AttestationPlatform.android).provider,
        isA<PlayIntegrityProvider>(),
      );
    });

    test('falls back to the unsupported provider on other platforms', () {
      expect(
        serviceFor(AttestationPlatform.other).provider,
        isA<UnsupportedAttestationProvider>(),
      );
    });

    test('fails closed on Android without a cloud project number', () async {
      await expectLater(
        serviceFor(AttestationPlatform.android).accessToken(),
        throwsA(
          isA<QuranAttestationException>().having(
            (error) => error.message,
            'message',
            contains('PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER'),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
      expect(appAttest.generatedKeys, 0);
    });

    test('honours an explicitly injected provider', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://worker.example'))
        ..httpClientAdapter = adapter;
      final service = QuranAttestationService(
        workerOrigin: 'https://worker.example',
        appAttest: appAttest,
        keyStore: keyStore,
        platform: () => AttestationPlatform.android,
        provider: _StubProvider(),
        client: dio,
      );

      expect(await service.accessToken(), 'stub-token');
      expect(adapter.requests, isEmpty);
    });
  });

  group('PlayIntegrityProvider', () {
    const storageKey = 'qf_play_integrity_id_worker.example';
    late _FakePlayIntegrityClient playIntegrity;
    late PlayIntegrityProvider provider;

    setUp(() {
      playIntegrity = _FakePlayIntegrityClient();
      final dio = Dio(BaseOptions(baseUrl: 'https://worker.example'))
        ..httpClientAdapter = adapter;
      provider = PlayIntegrityProvider(
        workerOrigin: 'https://worker.example',
        playIntegrity: playIntegrity,
        keyStore: keyStore,
        client: dio,
        cloudProjectNumber: 1234567890,
      );
    });

    test('binds the server challenge into the integrity token', () async {
      final token = await provider.obtainToken();

      expect(token.value, 'play-integrity-access-token');
      expect(token.expiresIn, const Duration(seconds: 600));
      expect(playIntegrity.nonces, ['integrity-challenge']);
      expect(playIntegrity.lastCloudProjectNumber, 1234567890);
      expect(adapter.requests.map((request) => request.path), [
        '/v1/attest/challenge',
        '/v1/attest/play-integrity',
      ]);

      final exchange = adapter.requests.last.data! as Map<String, dynamic>;
      expect(exchange['challenge'], 'integrity-challenge');
      expect(
        exchange['integrity_token'],
        'integrity-token-for-integrity-challenge',
      );
    });

    test('generates an identifier the proxy accepts as a key id', () async {
      await provider.obtainToken();

      expect(keyStore.values[storageKey], matches(r'^[A-Za-z0-9+/]{43}=$'));
    });

    test('reuses the stored identifier across refreshes', () async {
      await provider.obtainToken();
      final storedId = keyStore.values[storageKey];
      await provider.obtainToken();

      expect(storedId, isNotNull);
      expect(keyStore.values[storageKey], storedId);
      expect(playIntegrity.nonces, hasLength(2));
    });

    test('never requests an integrity token without a challenge', () async {
      playIntegrity.error = const QuranAttestationException(
        'Google Play Integrity is unavailable on this device.',
      );

      await expectLater(
        provider.obtainToken(),
        throwsA(isA<QuranAttestationException>()),
      );
      expect(adapter.requests.map((request) => request.path), [
        '/v1/attest/challenge',
      ]);
    });
  });
}
