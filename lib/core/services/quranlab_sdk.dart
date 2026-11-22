import 'package:quranlab_tajweedformer/quranlab_tajweedformer.dart';

import 'quran_api_service.dart';

/// Quran Lab's TajweedFormer SDK: it hears recitation and reports what it
/// heard. The app key comes from `--dart-define-from-file=quranlab.json` when
/// set, otherwise from the app's proxy, which serves it to attested installs.
class QuranLabSdk {
  QuranLabSdk._();

  static const String buildKey = String.fromEnvironment('QURANLAB_KEY');

  static Future<TajweedClient>? _client;

  /// The one client for this process.
  static Future<TajweedClient> client({QuranApiService? api}) {
    return _client ??= _create(api).catchError(
      (Object error, StackTrace stackTrace) {
        _client = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  static Future<TajweedClient> _create(QuranApiService? api) async {
    final key = buildKey.isNotEmpty
        ? buildKey
        : await (api ?? QuranApiService()).fetchQuranLabKey();
    return TajweedClient.create(key);
  }
}
