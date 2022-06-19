import 'package:uuid/uuid.dart';

class Guid {
  static Uuid _uuidGenerator = Uuid();
  static const String Empty = '00000000-0000-0000-0000-000000000000';
  static String newGuid() {
    return _uuidGenerator.v4();
  }
}
