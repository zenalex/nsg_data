import 'package:nsg_data/dataFields/dateField.dart';
import 'package:nsg_data/dataFields/stringField.dart';
import 'package:nsg_data/nsg_data_item.dart';

class CardItem extends NsgDataItem {
  @override
  void initialize() {
    addfield(NsgDataStringField('Id'), primaryKey: true); //GUID
    addfield(NsgDataStringField('CardNumber')); //EAN128
    addfield(NsgDataStringField('Title')); //Name of card
    addfield(NsgDataDateField('IssueDate')); //Date of issue
    addfield(NsgDataDateField('ValidUntil')); //Valid until date
    //addfield(NsgDataBoolField('Activated')); //Is card activated
  }

  @override
  NsgDataItem getNewObject() => CardItem();

  String get id => getFieldValue('Id').toString();
  set id(String value) => setFieldValue('Id', value);
  String get cardNumber => getFieldValue('CardNumber').toString();
  set cardNumber(String value) => setFieldValue('CardNumber', value);
  String get title => getFieldValue('Title').toString();
  set title(String value) => setFieldValue('Title', value);
  DateTime get issueDate => getFieldValue('IssueDate') as DateTime;
  set issueDate(DateTime value) => setFieldValue('IssueDate', value);
  DateTime get validUntil => getFieldValue('ValidUntil') as DateTime;
  set validUntil(DateTime value) => setFieldValue('ValidUntil', value);

  @override
  String get apiRequestItems {
    return '/Api/Data/GetCard';
  }
}
