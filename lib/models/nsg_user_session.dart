import 'package:nsg_data/nsg_data.dart';

mixin NsgUserSession on NsgDataItem {
  String get device;
  set device(String value);
  DateTime get dateCreated;
  set dateCreated(DateTime value);
  DateTime get dateLastUsed;
  set dateLastUsed(DateTime value);
  String get appVersion;
  @override
  String get apiRequestItems {
    return '/Api/Auth/GetUserSessions';
  }
}
