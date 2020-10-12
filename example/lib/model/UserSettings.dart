import 'package:example/model/cityItem.dart';
import 'package:nsg_data/dataFields/referenceField.dart';
import 'package:nsg_data/dataFields/stringField.dart';
import 'package:nsg_data/nsg_data_item.dart';

class UserSettingsItem extends NsgDataItem {
  static String get name_userId => 'UserId';
  static String get name_userName => 'UserName';
  static String get name_role => 'Role';
  static String get name_countryId => 'CountryId';
  static String get name_cityId => 'CityId';
  static String get name_leagueId => 'LeagueId';
  static String get name_teamId => 'TeamId';

  @override
  void initialize() {
    addfield(NsgDataStringField(name_userId), primaryKey: true);
    addfield(NsgDataStringField(name_userName));
    addfield(NsgDataStringField(name_role));
    addfield(NsgDataStringField(name_countryId));
    addfield(NsgDataReferenceField<CityItem>(name_cityId));
    addfield(NsgDataStringField(name_leagueId));
    addfield(NsgDataStringField(name_teamId));
  }

  @override
  NsgDataItem getNewObject() => UserSettingsItem();

  String get userId => getFieldValue(name_userId).toString();
  set userId(String value) => setFieldValue(name_userId, value);
  String get userName => getFieldValue(name_userName).toString();
  set userName(String value) => setFieldValue(name_userName, value);
  String get role => getFieldValue(name_role).toString();
  set role(String value) => setFieldValue(name_role, value);
  String get countryId => getFieldValue(name_countryId).toString();
  set countryId(String value) => setFieldValue(name_countryId, value);
  CityItem get city => getReferent(name_cityId);
  Future<CityItem> cityAsync() async {
    return await getReferentAsync<CityItem>(name_cityId);
  }

  set city(CityItem value) => setFieldValue(name_cityId, value);
  String get leagueId => getFieldValue(name_leagueId).toString();
  set leagueId(String value) => setFieldValue(name_leagueId, value);
  String get teamId => getFieldValue(name_teamId).toString();
  set teamId(String value) => setFieldValue(name_teamId, value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetUserSettings';
  }
}
