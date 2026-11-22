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

  test('a long vowel with another quality is a mistake', () {
    final heard = [..._hamd.sublist(0, 3), u('ل ع aa ل a م uu ن')];
    expect(
      _aligner().align(flat(heard), isFinal: true),
      'الحمد لله رب لعالمون',
    );
  });

  test('a short vowel with another quality is a mistake', () {
    final malik = u('م aa ل i ك i');
    final aligner = TajweedRecitationAligner([
      TajweedExpectedAyah(
        referenceWords: [malik, u('ي a و م i'), u('د ii ن')],
        textWords: ['مالك', 'يوم', 'الدين'],
      ),
    ]);
    final heard = [u('م aa ل i ك a'), u('ي a و م i'), u('د ii ن')];
    expect(aligner.align(flat(heard), isFinal: true), 'مالكا يوم الدين');
  });

  test('a short vowel inside a word is not judged by its quality', () {
    final aligner = TajweedRecitationAligner([
      TajweedExpectedAyah(
        referenceWords: [u('ء a ں ذ i ر'), u('ق a و م a ك a')],
        textWords: ['أنذر', 'قومك'],
      ),
    ]);
    final heard = [u('ء a ں ذ a ر a'), u('ق a و م a ك a')];
    expect(aligner.align(flat(heard), isFinal: true), 'أنذر قومك');
  });

  test('extra words between ayahs do not spoil the words before', () {
    final heard = [..._hamd, u('ي a س ء a ل u'), ..._rahman];
    final text = _aligner().align(flat(heard), isFinal: true);
    expect(text, startsWith('الحمد لله رب العالمين '));
    expect(text, isNot(contains('الحمد لله رب العالمين الرحمن')));
  });

  test('sound before the first word does not spoil it', () {
    final heard = [u('ت i ش ح a ر'), ..._hamd];
    expect(
      _aligner().align(flat(heard), isFinal: true),
      'الحمد لله رب العالمين',
    );
  });

  test('an unfinished الم shows no stray letter', () {
    final aligner = TajweedRecitationAligner([
      TajweedExpectedAyah(
        referenceWords: [u('ء a ل i ف'), u('ل aa م'), u('م ii م')],
        textWords: const ['الم'],
      ),
    ]);
    expect(aligner.align(u('ء a ل i ف ل aa م'), isFinal: true), '');
  });

  test('sound before a resumed word does not spoil it', () {
    final heard = [u('ء ii'), _hamd[2], _hamd[3]];
    expect(_aligner().align(flat(heard), isFinal: true), 'رب العالمين');
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

  test('words that recur are matched in the ayah being recited', () {
    // Units of 1:1 to 1:3 as served by the TajweedFormer reference.
    final rahman = u('ر a ح م aa ن i');
    final rahim = u('ر a ح ii م');
    final aligner = TajweedRecitationAligner([
      TajweedExpectedAyah(
        referenceWords: [u('ب i س م i'), u('ل aa ه i'), rahman, rahim],
        textWords: ['بسم', 'الله', 'الرحمن', 'الرحيم'],
      ),
      TajweedExpectedAyah(
        referenceWords: [
          u('ء a ل ح a م د u'),
          u('ل i ل aa ه i'),
          u('ر a ب i'),
          u('ل ع aa ل a م ii ن'),
        ],
        textWords: ['الحمد', 'لله', 'رب', 'العالمين'],
      ),
      TajweedExpectedAyah(
        referenceWords: [u('ء a ر a ح م aa ن i'), rahim],
        textWords: ['الرحمن', 'الرحيم'],
      ),
    ]);
    // A wrong attempt at 1:3, then repeats without the opening hamza.
    final heard = flat([
      u('ب i س م i'),
      u('ل aa ه i'),
      rahman,
      rahim,
      u('a ل ح a م د u'),
      u('ل i ل aa ه i'),
      u('ر a ب i'),
      u('ل ع aa ل a م ii ن'),
      u('a م ن i'),
      rahim,
      rahman,
      rahim,
      u('ء a ر a ح م aa ن i'),
      rahim,
      rahman,
      rahim,
    ]);
    expect(
      aligner.align(heard, isFinal: true),
      'بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم',
    );
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
