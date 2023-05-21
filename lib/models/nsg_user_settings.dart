import 'package:nsg_data/nsg_data.dart';

mixin NsgUserSettings {
  String get id;
  String get userId;
  String get name;
  set name(String value);
  String get settings;
  set settings(String value);
  static NsgUserSettingsController? controller;
}
