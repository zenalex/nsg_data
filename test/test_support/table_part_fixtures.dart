import 'package:nsg_data/nsg_data.dart';

class TablePartRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameLabel = 'label';

  @override
  String get typeName => 'TablePartRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameLabel), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TablePartRow();

  @override
  String get apiRequestItems => '/Data/TablePartRow';

  @override
  String get id => getFieldValue(nameId).toString();

  @override
  set id(String value) => setFieldValue(nameId, value);

  String get label => getFieldValue(nameLabel).toString();

  set label(String value) => setFieldValue(nameLabel, value);
}

class TablePartOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameRows = 'rows';

  @override
  String get typeName => 'TablePartOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(
      NsgDataReferenceListField<TablePartRow>(nameRows),
      primaryKey: false,
    );
  }

  @override
  NsgDataItem getNewObject() => TablePartOwner();

  @override
  String get apiRequestItems => '/Data/TablePartOwner';

  @override
  String get id => getFieldValue(nameId).toString();

  @override
  set id(String value) => setFieldValue(nameId, value);
}

void ensureTablePartFixturesRegistered() {
  if (!NsgDataClient.client.isRegistered(TablePartRow)) {
    NsgDataClient.client.registerDataItem(TablePartRow());
  }
  if (!NsgDataClient.client.isRegistered(TablePartOwner)) {
    NsgDataClient.client.registerDataItem(TablePartOwner());
  }
}

TablePartOwner makeTablePartOwner({
  required String id,
  List<TablePartRow>? rows,
}) {
  ensureTablePartFixturesRegistered();
  final o = TablePartOwner()..id = id;
  o.setFieldValue(TablePartOwner.nameRows, rows ?? <TablePartRow>[]);
  return o;
}

TablePartRow makeTablePartRow({required String id, String label = ''}) {
  ensureTablePartFixturesRegistered();
  final r = TablePartRow()
    ..id = id
    ..label = label;
  return r;
}
