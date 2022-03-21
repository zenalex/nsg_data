class NsgComparisonOperator {
  final int value;
  final String name;
  const NsgComparisonOperator(this.name, this.value);

  static const NsgComparisonOperator none = NsgComparisonOperator("None", 0);
  static const NsgComparisonOperator equal = NsgComparisonOperator("Equal", 1);
  static const NsgComparisonOperator notEqual =
      NsgComparisonOperator("NotEqual", 2);
  static const NsgComparisonOperator greater =
      NsgComparisonOperator("Greater", 3);
  static const NsgComparisonOperator greaterOrEqual =
      NsgComparisonOperator("GreaterOrEqual", 4);
  static const NsgComparisonOperator less = NsgComparisonOperator("Less", 5);
  static const NsgComparisonOperator lessOrEqual =
      NsgComparisonOperator("LessOrEqual", 6);
  static const NsgComparisonOperator inList = NsgComparisonOperator("In", 7);
  static const NsgComparisonOperator beginWith =
      NsgComparisonOperator("BeginWith", 8);
  static const NsgComparisonOperator endWith =
      NsgComparisonOperator("EndWith", 9);
  static const NsgComparisonOperator contain =
      NsgComparisonOperator("Contain", 10);
  static const NsgComparisonOperator containWords =
      NsgComparisonOperator("ContainWords", 11);
  static const NsgComparisonOperator cotContainWords =
      NsgComparisonOperator("NotContainWords", 12);
  static const NsgComparisonOperator inGroup =
      NsgComparisonOperator("InGroup", 13);
  static const NsgComparisonOperator groupsFrom =
      NsgComparisonOperator("GroupsFrom", 14);
  static const NsgComparisonOperator notGroupsFrom =
      NsgComparisonOperator("NotGroupsFrom", 15);
  static const NsgComparisonOperator equalOrEmpty =
      NsgComparisonOperator("EqualOrEmpty", 16);
  static const NsgComparisonOperator notInList =
      NsgComparisonOperator("NotIn", 17);
  static const NsgComparisonOperator notBeginWith =
      NsgComparisonOperator("NotBeginWith", 18);
  static const NsgComparisonOperator notEndWith =
      NsgComparisonOperator("NotEndWith", 19);
  static const NsgComparisonOperator notContain =
      NsgComparisonOperator("NotContain", 20);
  static const NsgComparisonOperator notInGroup =
      NsgComparisonOperator("NotInGroup", 21);
  static const NsgComparisonOperator notEqualOrEmpty =
      NsgComparisonOperator("NotEqualOrEmpty", 22);
  static const NsgComparisonOperator typeIn =
      NsgComparisonOperator("TypeIn", 23);
  static const NsgComparisonOperator typeEqual =
      NsgComparisonOperator("TypeEqual", 24);
  static const NsgComparisonOperator typeNotEqual =
      NsgComparisonOperator("TypeNotEqual", 25);

  static const Map<int, NsgComparisonOperator> allValues = {
    0: none,
    1: equal,
    2: notEqual,
    3: greater,
    4: greaterOrEqual,
    5: less,
    6: lessOrEqual,
    7: inList,
    8: beginWith,
    9: endWith,
    10: contain,
    11: containWords,
    12: cotContainWords,
    13: inGroup,
    14: groupsFrom,
    15: notGroupsFrom,
    16: equalOrEmpty,
    17: notInList,
    18: notBeginWith,
    19: notEndWith,
    20: notContain,
    21: notInGroup,
    22: notEqualOrEmpty,
    23: typeIn,
    24: typeEqual,
    25: typeNotEqual,
  };
}
