import 'dart:async';

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

    test('recognizes an IndexedDB connection closing failure', () {
      final error = Exception(
        "InvalidStateError: Failed to execute 'transaction' on 'IDBDatabase': "
        'The database connection is closing.',
      );

      expect(isRecoverableLocalDbError(error), isTrue);
    });

    test('does not hide unrelated programming errors', () {
      expect(isRecoverableLocalDbError(StateError('bad state')), isFalse);
    });
  });

  test('concurrent recovery callers await one reinitialization', () async {
    final gate = LocalDbReinitializationGate();
    final completion = Completer<bool>();
    var calls = 0;

    Future<bool> reinitialize() {
      calls++;
      return completion.future;
    }

    final first = gate.run(reinitialize);
    final second = gate.run(reinitialize);
    expect(calls, 1);

    completion.complete(true);
    expect(await Future.wait([first, second]), [isTrue, isTrue]);

    expect(await gate.run(reinitialize), isTrue);
    expect(calls, 2);
  });
}
