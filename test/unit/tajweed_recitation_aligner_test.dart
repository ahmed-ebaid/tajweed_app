import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/tajweed_recitation_aligner.dart';

List<int> u(String names) => [
  for (final name in names.split(' '))
    TajweedRecitationAligner.tj3Names.indexOf(name),
];

// Synthetic units in the tj3 vocabulary, for 1:2 and 1:3.
final _hamd = [
  u('ء a ل ح a م د u'),
  u('ل i ل aa ه i'),
  u('ر a ب i'),
  u('ل ع aa ل a م ii ن'),
];
final _rahman = [u('ء a ر ر a ح م aa ن i'), u('ر a ح ii م')];

List<int> flat(List<List<int>> words) => [for (final w in words) ...w];

TajweedRecitationAligner _aligner() => TajweedRecitationAligner([
  TajweedExpectedAyah(
    referenceWords: _hamd,
    textWords: ['الحمد', 'لله', 'رب', 'العالمين'],
  ),
  TajweedExpectedAyah(referenceWords: _rahman, textWords: ['الرحمن', 'الرحيم']),
]);

void main() {
  test('a correct recitation gives the expected words across ayahs', () {
    expect(
      _aligner().align(flat([..._hamd, ..._rahman]), isFinal: true),
      'الحمد لله رب العالمين الرحمن الرحيم',
    );
  });

  test('small vowel differences still match', () {
    final heard = [u('ء a ل ح a م د'), u('ل i ل aa ه'), _hamd[2]];
    expect(_aligner().align(flat(heard), isFinal: true), 'الحمد لله رب');
  });

  test('resuming mid-ayah starts at the recited word', () {
    expect(
      _aligner().align(flat([_hamd[2], _hamd[3]]), isFinal: true),
      'رب العالمين',
    );
  });

  test('a different word is spelled from what was heard', () {
    final heard = [_hamd[0], _hamd[1], u('ق a ل'), _hamd[3]];
    final text = _aligner().align(flat(heard), isFinal: true);
    expect(text, 'الحمد لله قل العالمين');
  });

  test('an unmatched last word waits while the take is live', () {
    final heard = [_hamd[0], u('ل i')];
    expect(_aligner().align(flat(heard), isFinal: false), 'الحمد');
    expect(_aligner().align(flat(heard), isFinal: true), 'الحمد ل');
  });

  test('the ta\'awwudh before the ayah is not judged', () {
    final heard = [...TajweedRecitationAligner.isti3adha, ...flat(_hamd)];
    expect(_aligner().align(heard, isFinal: true), 'الحمد لله رب العالمين');
  });

  test('a skipped word is left out', () {
    final heard = flat([_hamd[0], _hamd[1], _hamd[3]]);
    expect(_aligner().align(heard, isFinal: true), 'الحمد لله العالمين');
  });

  test('going back to repeat earlier words is not a mistake', () {
    final heard = flat([..._hamd.sublist(0, 3), ..._hamd.sublist(1)]);
    expect(_aligner().align(heard, isFinal: true), 'الحمد لله رب العالمين');
  });

  test('a wrong attempt repeated correctly passes and keeps earlier words', () {
    final basmala = [u('ب i س م i'), u('ل ل aa ه i'), ..._rahman];
    final aligner = TajweedRecitationAligner([
      TajweedExpectedAyah(
        referenceWords: basmala,
        textWords: ['بسم', 'الله', 'الرحمن', 'الرحيم'],
      ),
    ]);
    final wrong = [u('ء a ر ر a ه م aa ل i'), u('ر a ه ii ل')];
    final heard = flat([...basmala.sublist(0, 2), ...wrong, ..._rahman]);
    final live = [
      for (var n = 1; n <= heard.length; n++)
        aligner.align(heard.sublist(0, n), isFinal: false),
    ];
    expect(
      live.skipWhile((t) => !t.startsWith('بسم الله')),
      everyElement(startsWith('بسم الله')),
    );
    expect(aligner.align(heard, isFinal: true), 'بسم الله الرحمن الرحيم');
  });

  test('unequal word counts map reference words proportionally', () {
    final aligner = TajweedRecitationAligner([
      TajweedExpectedAyah(
        referenceWords: [u('ي aa ء a ي u ه a'), u('ن aa س')],
        textWords: ['يا', 'أيها', 'الناس'],
      ),
    ]);
    expect(
      aligner.align(flat([u('ي aa ء a ي u ه a'), u('ن aa س')]), isFinal: true),
      'يا أيها الناس',
    );
  });

  test('settled words are committed and later output keeps them', () {
    final aligner = TajweedRecitationAligner([
      for (var i = 0; i < 15; i++)
        TajweedExpectedAyah(
          referenceWords: _hamd,
          textWords: ['الحمد', 'لله', 'رب', 'العالمين'],
        ),
    ]);
    final units = flat([for (var i = 0; i < 15; i++) ..._hamd]);
    final expected = [
      for (var i = 0; i < 15; i++) 'الحمد لله رب العالمين',
    ].join(' ');
    final half = units.sublist(0, units.length ~/ 2);
    final first = aligner.align(
      half,
      isFinal: false,
      settledUnits: half.length,
    );
    expect(expected, startsWith(first));
    expect(
      aligner.align(units, isFinal: true, settledUnits: units.length),
      expected,
    );
  });

  test('splitUnits drops the word bar', () {
    final units = [...u('ر a ب i'), 1, ...u('ل ع aa ل a م ii ن')];
    expect(TajweedExpectedAyah.splitUnits(units, [0, 5]), [
      u('ر a ب i'),
      u('ل ع aa ل a م ii ن'),
    ]);
  });
}
