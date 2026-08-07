import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/core/constants/domain_enums.dart';

void main() {
  group('keluargaModule', () {
    test('category labels match the task spec exactly', () {
      expect(keluargaModule.targetCategoryLabel, 'keluargaku');
      expect(keluargaModule.distractorCategoryLabel, 'bukan keluarga');
    });

    test('id is ModuleId.keluarga', () {
      expect(keluargaModule.id, ModuleId.keluarga);
    });

    test('never uses a classifier — guardian supplies name/relationship directly',
        () {
      expect(keluargaModule.usesClassifier, isFalse);
    });

    test('distractors are bundled, never drawn from the child\'s own photo library',
        () {
      expect(keluargaModule.usesBundledDistractors, isTrue);
    });
  });
}
