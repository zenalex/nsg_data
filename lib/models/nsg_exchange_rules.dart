import '../dataFields/nsg_data_table.dart';

mixin NsgExchangeRules {
  String get objectType;
  set objectType(String value);
  int get periodicity;
  set periodicity(int value);
  bool get priorityForClient;
  set priorityForClient(bool value);
  NsgDataTable get mergingRules;
}

mixin NsgExchangeRulesMergingTable {
  String get fieldName;
  set fieldName(String value);
  bool get priorityForClient;
  set priorityForClient(bool value);
}
