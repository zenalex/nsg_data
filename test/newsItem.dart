import 'package:nsg_data/dataFields/dateField.dart';
import 'package:nsg_data/dataFields/dataImage.dart';
import 'package:nsg_data/dataFields/stringField.dart';
import 'package:nsg_data/nsg_data_item.dart';

class NewsItem extends NsgDataItem {
  @override
  void initialize() {
    addfield(NsgDataStringField('Id'), primaryKey: true);
    addfield(NsgDataDateField('Date'));
    addfield(NsgDataStringField('Title'));
    addfield(NsgDataStringField('Text'));
    addfield(NsgDataImageField('ImageUri'));
  }

  @override
  NsgDataItem getNewObject() => NewsItem();

  String get id => getFieldValue('Id').toString();
  set id(String value) => setFieldValue('Id', value);
  DateTime? get date => getFieldValue('Date') as DateTime?;
  set date(DateTime? value) => setFieldValue('Date', value);
  String get title => getFieldValue('Title').toString();
  set title(String value) => setFieldValue('Title', value);
  String get text => getFieldValue('Text').toString();
  set text(String value) => setFieldValue('Text', value);
  String get imageUri => getFieldValue('ImageUri').toString();
  set imageUri(String value) => setFieldValue('ImageUri', value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetNews';
  }
}
