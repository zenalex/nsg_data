import 'package:uuid/uuid.dart';

class Guid {
  static Uuid _uuidGenerator = Uuid();
  static String newGuid() {
    return _uuidGenerator.v4();
  }
}
