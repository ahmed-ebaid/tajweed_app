import '../../core/models/tajweed_models.dart';

typedef AyahReference = ({int surah, int ayah});

class RuleExampleReferences {
  const RuleExampleReferences._();

  // Most references were selected by the shortest-example scanner.
  // `izhar`, `shaddah`, and `waqf` are manually curated because the upstream
  // tajweed span data does not expose those rules reliably enough to auto-pick.
  static const Map<TajweedRule, String> audioCodes = {
    TajweedRule.ghunnah: '055064',
    TajweedRule.qalqalah: '089001',
    TajweedRule.maddTabeei: '052001',
    TajweedRule.maddMuttasil: '078026',
    TajweedRule.maddMunfasil: '108001',
    TajweedRule.maddLazim: '036001',
    TajweedRule.maddSilahSughra: '018005',
    TajweedRule.maddSilahKubra: '002255',
    TajweedRule.idghamWithGhunnah: '078026',
    TajweedRule.idghamWithoutGhunnah: '056003',
    TajweedRule.idghamShafawi: '026060',
    TajweedRule.idghamMutajanisayn: '074014',
    TajweedRule.ikhfa: '074002',
    TajweedRule.ikhfaShafawi: '079014',
    TajweedRule.iqlab: '080016',
    TajweedRule.izhar: '101011',
    TajweedRule.shaddah: '055064',
    TajweedRule.waqf: '103001',
    TajweedRule.sajdah: '053062',
    TajweedRule.hamzatWasl: '052001',
    TajweedRule.laamShamsiyah: '052001',
    TajweedRule.silent: '020028',
  };

  static AyahReference? referenceFor(TajweedRule rule) {
    final code = audioCodes[rule];
    if (code == null || code.length != 6) return null;

    final surah = int.tryParse(code.substring(0, 3));
    final ayah = int.tryParse(code.substring(3, 6));
    if (surah == null || ayah == null) return null;

    return (surah: surah, ayah: ayah);
  }

  static String codeForReference(AyahReference reference) {
    final surah = reference.surah.toString().padLeft(3, '0');
    final ayah = reference.ayah.toString().padLeft(3, '0');
    return '$surah$ayah';
  }
}
