import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/db/nsg_local_db.dart';

void main() {
  group('isRecoverableLocalDbError', () {
    test('recognizes the IndexedDB missing object store failure', () {
      final error = Exception(
        "NotFoundError: Failed to execute 'transaction' on 'IDBDatabase': "
        'One of the specified object stores was not found.',
      );

      expect(isRecoverableLocalDbError(error), isTrue);
    });

    test('keeps existing Hive recovery cases', () {
      expect(isRecoverableLocalDbError(Exception('compact failed')), isTrue);
      expect(isRecoverableLocalDbError(Exception('rename failed')), isTrue);
    });

    test('does not hide unrelated programming errors', () {
      expect(isRecoverableLocalDbError(StateError('bad state')), isFalse);
    });
  });
}
