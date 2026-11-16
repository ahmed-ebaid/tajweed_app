import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/services/quran_asr_speech_input.dart';
export '../../core/services/quran_asr_speech_input.dart'
    show quranAsrExperimentEnabled;

class QuranAsrExperimentScreen extends StatefulWidget {
  const QuranAsrExperimentScreen({super.key});

  @override
  State<QuranAsrExperimentScreen> createState() =>
      _QuranAsrExperimentScreenState();
}

class _QuranAsrExperimentScreenState extends State<QuranAsrExperimentScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel(
    'com.ebaidllc.tajweed_practice/quran_asr',
  );
  bool _available = false;
  bool _busy = true;
  bool _recording = false;
  String? _error;
  String? _transcript;
  double? _seconds;
  Timer? _limit;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'interrupted') {
        await _cancel();
        if (mounted) setState(() => _error = 'quran_asr_failed');
      }
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (!quranAsrExperimentEnabled) {
        setState(() {
          _busy = false;
          _error = 'quran_asr_unavailable';
        });
        return;
      }
      final available = await _channel.invokeMethod<bool>('available');
      if (available == null) {
        throw const FormatException(
          'Missing native model availability result.',
        );
      }
      if (mounted) {
        setState(() {
          _available = available;
          _busy = false;
          if (!available) _error = 'quran_asr_unavailable';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'quran_asr_unavailable';
        });
      }
    } catch (error) {
      debugPrint('Quran ASR initialization failed: $error');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'quran_asr_failed';
        });
      }
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _transcript = null;
      _seconds = null;
    });
    try {
      await _channel.invokeMethod<void>('start');
      if (!mounted || generation != _generation) return;
      setState(() {
        _recording = true;
        _busy = false;
      });
      _limit = Timer(const Duration(seconds: 30), () => unawaited(_check()));
    } on PlatformException catch (error) {
      _failed(generation, error);
    }
  }

  Future<void> _check() async {
    if (!_recording) return;
    final generation = _generation;
    _limit?.cancel();
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final report = await _channel.invokeMapMethod<String, dynamic>('check');
      if (!mounted || generation != _generation) return;
      if (report == null ||
          report['transcript'] is! String ||
          (report['transcript'] as String).trim().isEmpty ||
          report['inferenceSeconds'] is! num ||
          !(report['inferenceSeconds'] as num).isFinite ||
          (report['inferenceSeconds'] as num) < 0 ||
          report['durationSeconds'] is! num ||
          !(report['durationSeconds'] as num).isFinite ||
          (report['durationSeconds'] as num) <= 0 ||
          (report['durationSeconds'] as num) > 30) {
        throw const FormatException('Invalid experimental recognition result.');
      }
      setState(() {
        _busy = false;
        _transcript = report['transcript'] as String;
        _seconds = (report['inferenceSeconds'] as num).toDouble();
      });
    } on PlatformException catch (error) {
      _failed(generation, error);
    } on FormatException catch (error) {
      debugPrint('Quran ASR result failed: $error');
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _error = 'quran_asr_failed';
        });
      }
    }
  }

  void _failed(int generation, PlatformException error) {
    debugPrint('Quran ASR failed: ${error.code}');
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _recording = false;
      _error = 'quran_asr_failed';
    });
  }

  Future<void> _cancel({bool updateUi = true}) async {
    final generation = ++_generation;
    _limit?.cancel();
    if (updateUi && mounted && _available) {
      setState(() {
        _busy = true;
        _recording = false;
      });
    }
    try {
      await _channel.invokeMethod<void>('cancel');
      if (updateUi && mounted && generation == _generation && _available) {
        setState(() {
          _busy = false;
          _recording = false;
        });
      }
    } on PlatformException catch (error) {
      _failed(generation, error);
    } on MissingPluginException {
      // No engine means there is no native recording to cancel.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    unawaited(_cancel(updateUi: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('quran_asr_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.get('quran_asr_warning')),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              l10n.get(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_recording) Text(l10n.get('recording')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: !_available || _busy
                ? null
                : _recording
                ? _check
                : _start,
            icon: Icon(_recording ? Icons.stop : Icons.mic),
            label: Text(
              l10n.get(_recording ? 'quran_asr_check' : 'tap_to_record'),
            ),
          ),
          if (_recording ||
              (_busy && _available) ||
              (_error != null && _available))
            TextButton(
              onPressed: _cancel,
              child: Text(l10n.get('quran_asr_cancel')),
            ),
          if (_transcript != null) ...[
            const SizedBox(height: 16),
            Text(l10n.get('quran_asr_result')),
            SelectableText(_transcript!, textDirection: TextDirection.rtl),
            Text(
              '${l10n.get('quran_asr_time')}: ${_seconds!.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }
}
