import 'package:nsg_data/dataFields/referenceField.dart';
import 'package:nsg_data/dataFields/stringField.dart';
import 'package:nsg_data/nsg_data_item.dart';

import 'countryItem.dart';

class UserSettingsItem extends NsgDataItem {
  @override
  void initialize() {
    addfield(NsgDataStringField('UserId'), primaryKey: true);
    addfield(NsgDataStringField('UserName'));
    addfield(NsgDataStringField('Role'));
    addfield(NsgDataReferenceField<CountryItem>('CountryId'));
    addfield(NsgDataStringField('CityId'));
    addfield(NsgDataStringField('LeagueId'));
    addfield(NsgDataStringField('TeamId'));
  }

  @override
  NsgDataItem getNewObject() => UserSettingsItem();

  String get userId => getFieldValue('UserId').toString();
  set userId(String value) => setFieldValue('UserId', value);
  String get userName => getFieldValue('UserName').toString();
  set userName(String value) => setFieldValue('UserName', value);
  String get role => getFieldValue('Role').toString();
  set role(String value) => setFieldValue('Role', value);
  CountryItem? get country => getFieldValue('CountryId') as CountryItem?;
  set countryId(CountryItem value) => setFieldValue('CountryId', value);
  String get cityId => getFieldValue('CityId').toString();
  set cityId(String value) => setFieldValue('CityId', value);
  String get leagueId => getFieldValue('LeagueId').toString();
  set leagueId(String value) => setFieldValue('LeagueId', value);
  String get teamId => getFieldValue('TeamId').toString();
  set teamId(String value) => setFieldValue('TeamId', value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetUserSettings';
  }
}
