import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/quran_attestation_service.dart';

enum ReaderFailureKind { connection, timeout, verification, server, unknown }

class ReaderLoadFailure {
  final ReaderFailureKind kind;
  final String? requestId;

  const ReaderLoadFailure(this.kind, {this.requestId});

  factory ReaderLoadFailure.fromError(Object error) {
    if (error is TimeoutException) {
      return const ReaderLoadFailure(ReaderFailureKind.timeout);
    }
    if (error is QuranAttestationException) {
      return const ReaderLoadFailure(ReaderFailureKind.verification);
    }
    if (error is DioException) {
      if (error.error is DioException ||
          error.error is QuranAttestationException ||
          error.error is TimeoutException) {
        return ReaderLoadFailure.fromError(error.error!);
      }
      final rawId = error.response?.headers.value('x-request-id');
      final requestId =
          rawId != null && RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(rawId)
          ? rawId
          : null;
      final status = error.response?.statusCode;
      final kind = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => ReaderFailureKind.timeout,
        DioExceptionType.connectionError => ReaderFailureKind.connection,
        _ when status == 401 || status == 403 => ReaderFailureKind.verification,
        _ when status != null && status >= 500 => ReaderFailureKind.server,
        _ => ReaderFailureKind.unknown,
      };
      return ReaderLoadFailure(kind, requestId: requestId);
    }
    return const ReaderLoadFailure(ReaderFailureKind.unknown);
  }

  String get reference =>
      'QURAN_${kind.name.toUpperCase()}${requestId == null ? '' : ' / $requestId'}';
}

class ReaderLoadFailureView extends StatelessWidget {
  final ReaderLoadFailure failure;
  final VoidCallback onRetry;

  const ReaderLoadFailureView({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(l10n.get('verses_load_failed'), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l10n.get('reader_failure_${failure.kind.name}'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              failure.reference,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.get('retry'))),
          ],
        ),
      ),
    );
  }
}
