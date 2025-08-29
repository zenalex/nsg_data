import 'package:nsg_data/nsg_data.dart';

class NsgDataBaseReferenceField<T extends NsgDataItem> extends NsgDataField {
  NsgDataBaseReferenceField(super.name);

  Type get referentElementType => T;

  Type get referentType => NsgDataItem;
}
