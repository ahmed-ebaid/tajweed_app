import 'package:integration_test/integration_test.dart';

import '../test/widget/rules_library_regression_test.dart' as regression;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regression.main();
}
