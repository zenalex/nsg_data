import 'package:nsg_data/dataFields/stringField.dart';
import 'package:nsg_data/nsg_data_item.dart';

class CountryItem extends NsgDataItem {
  @override
  void initialize() {
    addField(NsgDataStringField('Id'));
    addField(NsgDataStringField('Title'));
  }

  @override
  NsgDataItem getNewObject() => CountryItem();

  String get id => getFieldValue('Id').toString();
  set id(String value) => setFieldValue('Id', value);
  String get title => getFieldValue('Title').toString();
  set title(String value) => setFieldValue('Title', value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetCountry';
  }
}

class CityItem extends NsgDataItem {
  @override
  void initialize() {
    addField(NsgDataStringField('Id'), primaryKey: true);
    addField(NsgDataStringField('Title'));
    addField(NsgDataStringField('CountryId'));
  }

  @override
  NsgDataItem getNewObject() => CityItem();

  String get id => getFieldValue('Id').toString();
  set id(String value) => setFieldValue('Id', value);
  String get title => getFieldValue('Title').toString();
  set title(String value) => setFieldValue('Title', value);
  String get countryId => getFieldValue('CountryId').toString();
  set countryId(String value) => setFieldValue('CountryId', value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetCity';
  }
}
