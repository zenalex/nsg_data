import 'package:nsg_data/nsg_data_fieldlist.dart';
import 'nsg_data_item.dart';

class NsgDataClient {
  NsgDataClient._();

  static NsgDataClient client = NsgDataClient._();
  String serverUri = 'http://192.168.1.20:5073';
  List<String> serversUri;
  Duration requestDuration = Duration(seconds: 15);
  //static final String serverUri1 = "http://alex.nsgsoft.ru:5073";
  //static final String serverUri2 = "http://192.168.1.20:5073";

  final Map<Type, NsgDataItem> _registeredItems = <Type, NsgDataItem>{};
  final Map<Type, NsgFieldList> _fieldList = <Type, NsgFieldList>{};

  void registerDataItem(NsgDataItem item) {
    _registeredItems[item.runtimeType] = item;
    _fieldList[item.runtimeType] = NsgFieldList();
    item.initialize();
  }

  NsgFieldList getFieldList(NsgDataItem item) {
    assert(_registeredItems.containsKey(item.runtimeType));
    return _fieldList[item.runtimeType];
  }

  NsgDataItem getNewObject(Type type) {
    assert(_registeredItems.containsKey(type));
    return _registeredItems[type].getNewObject();
  }
}
