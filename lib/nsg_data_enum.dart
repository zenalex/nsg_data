import 'package:nsg_data/nsg_data.dart';

class NsgEnum extends NsgDataItem {
  final String name;
  final int value;

  NsgEnum({this.value = 0, required this.name});

  static Map<Type, Map<int, NsgEnum>> listAllValues = {};
  static Map<int, NsgEnum> _getAll(Type type) {
    assert(listAllValues.containsKey(type));
    return listAllValues[type]!;
  }

  static List<NsgEnum> _getAllValues(Type type) {
    var list = <NsgEnum>[];
    list.addAll(_getAll(type).values);
    return list;
  }

  @override
  void initialize() {
    throw Exception('initialize for type {runtimeType} is not defined');
  }

  List<NsgEnum> getAll() => _getAllValues(runtimeType);

  static NsgEnum fromValue(Type type, int v) {
    var map = _getAll(type);
    if (!map.containsKey(v)) {
      v = 0;
      return map[v]!;
      //throw Exception('Wrong value $v');
    }
    return map[v]!;
  }

  static NsgEnum fromString(Type type, String v) {
    return _getAllValues(type).firstWhere((element) => element.name == v);
  }

  @override
  String toString() {
    return name;
  }
}
