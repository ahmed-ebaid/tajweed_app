import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/services/onboarding_service.dart';

class FirstRunOnboardingLauncher extends StatefulWidget {
  final Widget child;
  final OnboardingService? service;

  const FirstRunOnboardingLauncher({super.key, required this.child, this.service});

  @override
  State<FirstRunOnboardingLauncher> createState() => _FirstRunOnboardingLauncherState();
}

class _FirstRunOnboardingLauncherState extends State<FirstRunOnboardingLauncher> {
  late final OnboardingService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_service.shouldShowAutomatically) return;
      _service.markPresented();
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => OnboardingScreen(service: _service)));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class OnboardingScreen extends StatefulWidget {
  final OnboardingService service;

  const OnboardingScreen({super.key, required this.service});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 6;

  final PageController _controller = PageController();
  late final bool _initialDismissal;
  late bool _dontShowAgain;
  int _page = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _initialDismissal = widget.service.isDismissed;
    _dontShowAgain = _initialDismissal;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await widget.service.updateDismissal(initialValue: _initialDismissal, currentValue: _dontShowAgain);
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _close();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_closing) {
          widget.service.updateDismissal(
            initialValue: _initialDismissal,
            currentValue: _dontShowAgain,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.get('onboarding_title')),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              key: const Key('onboarding_close'),
              tooltip: l10n.get('onboarding_close'),
              onPressed: _close,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  key: const Key('onboarding_pages'),
                  controller: _controller,
                  itemCount: _pageCount,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => _GuidePage(index: index),
                ),
              ),
              Semantics(
                label: l10n.get('onboarding_page_indicator'),
                value: '${_page + 1} / $_pageCount',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pageCount,
                    (index) => AnimatedContainer(
                      key: Key('onboarding_indicator_$index'),
                      duration: const Duration(milliseconds: 180),
                      width: index == _page ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _page ? colorScheme.primary : colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              CheckboxListTile(
                key: const Key('onboarding_dont_show_again'),
                value: _dontShowAgain,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(l10n.get('onboarding_dont_show_again')),
                onChanged: (value) => setState(() => _dontShowAgain = value ?? false),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('onboarding_back'),
                        onPressed: _page == 0 ? null : _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(l10n.get('onboarding_back')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('onboarding_next'),
                        onPressed: _next,
                        iconAlignment: IconAlignment.end,
                        icon: Icon(_page == _pageCount - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                        label: Text(l10n.get(_page == _pageCount - 1 ? 'onboarding_done' : 'onboarding_next')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  final int index;

  const _GuidePage({required this.index});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n.get('onboarding_${index + 1}_title');
    final caption = l10n.get('onboarding_${index + 1}_caption');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 520;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 24, 20, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: l10n.get('onboarding_mockup_semantics_${index + 1}'),
                  image: true,
                  child: ExcludeSemantics(
                    child: index == 4 || index == 5
                        ? _MushafMockup(
                            page: index,
                            height: compact ? 245 : 330,
                            calloutLabel: l10n.get('onboarding_mockup_callout_${index + 1}'),
                          )
                        : _ReaderMockup(
                            page: index,
                            height: compact ? 245 : 330,
                            calloutLabel: l10n.get('onboarding_mockup_callout_${index + 1}'),
                          ),
                  ),
                ),
                SizedBox(height: compact ? 16 : 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReaderMockup extends StatelessWidget {
  final int page;
  final double height;
  final String calloutLabel;

  const _ReaderMockup({required this.page, required this.height, required this.calloutLabel});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: height,
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(color: colors.shadow.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: colors.primaryContainer.withValues(alpha: 0.55),
                child: Row(
                  children: [
                    Icon(Icons.menu_rounded, size: 18, color: colors.onPrimaryContainer),
                    const Spacer(),
                    Text(
                      'سورة الملك',
                      style: TextStyle(
                        fontFamily: 'AmiriQuran',
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.lightbulb_outline_rounded, size: 20, color: colors.onPrimaryContainer),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MockAyah(highlightTajweed: page == 0),
                      const SizedBox(height: 15),
                      const _MockAyah(),
                      const SizedBox(height: 15),
                      const _MockAyah(short: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _InteractionOverlay(page: page, label: calloutLabel),
        ],
      ),
    );
  }
}

/// Mockup resembling the Mushaf page view (used for the Hizb-boundary and
/// page-bookmark guide pages), so users can tell these features live in the
/// printed-page reader, not the ayah-by-ayah view.
class _MushafMockup extends StatelessWidget {
  final int page;
  final double height;
  final String calloutLabel;

  const _MushafMockup({required this.page, required this.height, required this.calloutLabel});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const accent = Color(0xFF0B5C45);
    const fill = Color(0xFFDDECE6);
    return Container(
      width: double.infinity,
      height: height,
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(color: colors.shadow.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: fill,
                child: Row(
                  children: [
                    const Text('١٨', style: TextStyle(fontFamily: 'AmiriQuran', color: accent, fontSize: 13)),
                    const Spacer(),
                    Text(
                      'سورة الملك',
                      style: TextStyle(fontFamily: 'AmiriQuran', color: accent, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Text('جزء ٢٩', style: TextStyle(fontFamily: 'AmiriQuran', color: accent, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          _MushafPrintedLineMock(text: 'تَبَارَكَ الَّذِي بِيَدِهِ الْمُلْكُ وَهُوَ'),
                          _MushafPrintedLineMock(text: 'عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ ۝١ الَّذِي'),
                          _MushafPrintedLineMock(text: 'خَلَقَ الْمَوْتَ وَالْحَيَاةَ لِيَبْلُوَكُمْ'),
                          _MushafPrintedLineMock(text: 'أَيُّكُمْ أَحْسَنُ عَمَلًا ۝٢'),
                        ],
                      ),
                      if (page == 4)
                        Positioned(
                          left: 0,
                          top: 60,
                          child: Tooltip(
                            message: 'حزب ١٤ ربع ٣',
                            child: Container(
                              width: 14,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                                border: Border.all(color: accent, width: 0.8),
                              ),
                              child: const Text(
                                '\u06DE',
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: 11,
                                  height: 1,
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _InteractionOverlay(page: page, label: calloutLabel),
        ],
      ),
    );
  }
}

class _MushafPrintedLineMock extends StatelessWidget {
  final String text;

  const _MushafPrintedLineMock({required this.text});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 19, height: 1.9, color: base),
      ),
    );
  }
}

class _MockAyah extends StatelessWidget {
  final bool highlightTajweed;
  final bool short;

  const _MockAyah({this.highlightTajweed = false, this.short = false});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            short ? 'تَبَارَكَ الَّذِي' : 'الَّذِي خَلَقَ الْمَوْتَ وَالْحَيَاةَ',
            style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 20, height: 1.7, color: base),
          ),
          if (highlightTajweed)
            Text(
              ' لِيَبْلُوَكُمْ',
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 20,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '۝٢',
            style: TextStyle(fontFamily: 'AmiriQuran', color: Theme.of(context).colorScheme.secondary),
          ),
        ],
      ),
    );
  }
}

class _InteractionOverlay extends StatelessWidget {
  final int page;
  final String label;

  const _InteractionOverlay({required this.page, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overlayColor = colors.primary;
    final config = switch (page) {
      0 => (const Alignment(-0.25, -0.32), Icons.touch_app_rounded, label, const Size(150, 52)),
      1 => (const Alignment(0.88, -0.89), Icons.lightbulb_rounded, label, const Size(178, 58)),
      2 => (const Alignment(0.18, -0.10), Icons.graphic_eq_rounded, label, const Size(110, 52)),
      3 => (const Alignment(-0.60, 0.40), Icons.bookmark_add_rounded, label, const Size(125, 52)),
      4 => (const Alignment(-0.88, -0.02), Icons.adjust_rounded, label, const Size(165, 52)),
      _ => (const Alignment(0.0, 0.82), Icons.bookmark_rounded, label, const Size(145, 52)),
    };

    return Align(
      alignment: config.$1,
      child: Container(
        width: config.$4.width,
        height: config.$4.height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: overlayColor, width: 2),
          boxShadow: [
            BoxShadow(color: colors.shadow.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(config.$2, color: overlayColor, size: 23),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                config.$3,
                textDirection: TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
