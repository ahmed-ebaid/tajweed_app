import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/reader_localizations.dart';
import 'package:tajweed_practice/core/services/quran_attestation_service.dart';
import 'package:tajweed_practice/features/reader/widgets/reader_load_failure.dart';

void main() {
  DioException failure(
    DioExceptionType type, {
    int? status,
    Object? error,
    String requestId = 'safe-request-123',
  }) {
    final options = RequestOptions(path: '/verses');
    return DioException(
      requestOptions: options,
      type: type,
      error: error,
      response: status == null
          ? null
          : Response(
              requestOptions: options,
              statusCode: status,
              headers: Headers.fromMap({
                'x-request-id': [requestId],
              }),
            ),
    );
  }

  test('classifies network, timeout, verification and server errors', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      expect(
        ReaderLoadFailure.fromError(failure(type)).kind,
        ReaderFailureKind.timeout,
      );
    }
    expect(
      ReaderLoadFailure.fromError(
        failure(DioExceptionType.connectionError),
      ).kind,
      ReaderFailureKind.connection,
    );
    for (final status in [401, 403, 502, 503]) {
      final result = ReaderLoadFailure.fromError(
        failure(DioExceptionType.badResponse, status: status),
      );
      expect(
        result.kind,
        status < 500
            ? ReaderFailureKind.verification
            : ReaderFailureKind.server,
      );
      expect(result.requestId, 'safe-request-123');
    }
    expect(
      ReaderLoadFailure.fromError(TimeoutException('private details')).kind,
      ReaderFailureKind.timeout,
    );
    expect(
      ReaderLoadFailure.fromError(
        failure(
          DioExceptionType.unknown,
          error: const QuranAttestationException('private details'),
        ),
      ).kind,
      ReaderFailureKind.verification,
    );
    expect(
      ReaderLoadFailure.fromError(
        failure(
          DioExceptionType.unknown,
          error: failure(DioExceptionType.receiveTimeout),
        ),
      ).kind,
      ReaderFailureKind.timeout,
    );
  });

  test('references never expose arbitrary server or exception content', () {
    final result = ReaderLoadFailure.fromError(
      failure(
        DioExceptionType.badResponse,
        status: 503,
        requestId: '<private details>',
      ),
    );
    expect(result.reference, 'QURAN_SERVER');
    expect(
      ReaderLoadFailure.fromError(StateError('secret')).reference,
      'QURAN_UNKNOWN',
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('failure screen is localized in ${locale.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final kind in ReaderFailureKind.values) {
        var retried = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: ReaderLoadFailureView(
                failure: ReaderLoadFailure(kind),
                onRetry: () => retried = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = readerTranslations[locale.languageCode]!;
        expect(find.text(strings['verses_load_failed']!), findsOneWidget);
        expect(
          find.text(strings['reader_failure_${kind.name}']!),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
        await tester.tap(find.text(strings['retry']!));
        expect(retried, isTrue);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
