import 'package:nsg_data/dataFields/stringField.dart';
import 'package:nsg_data/nsg_data_item.dart';

class CityItem extends NsgDataItem {
  static String get name_id => 'Id';
  static String get name_title => 'Title';
  static String get name_countryId => 'CountryId';

  @override
  void initialize() {
    addfield(NsgDataStringField(name_id), primaryKey: true);
    addfield(NsgDataStringField(name_title));
    addfield(NsgDataStringField(name_countryId));
  }

  @override
  NsgDataItem getNewObject() => CityItem();

  String get id => getFieldValue(name_id).toString();
  set id(String value) => setFieldValue(name_id, value);
  String get title => getFieldValue(name_title).toString();
  set title(String value) => setFieldValue(name_title, value);
  String get countryId => getFieldValue(name_countryId).toString();
  set countryId(String value) => setFieldValue(name_countryId, value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetCity';
  }
}
