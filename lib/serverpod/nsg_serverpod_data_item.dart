import 'package:nsg_data/nsg_data.dart';

abstract class NsgServerpodDataItem<TServerpodModel> extends NsgDataItem {
  TServerpodModel createServerpodModel(Map<String, dynamic> json);

  TServerpodModel toServerpodModel() {
    return createServerpodModel(toServerpodJson());
  }

  @override
  Map<String, dynamic> toServerpodJson({List<String> excludeFields = const []}) {
    return toJson(excludeFields: excludeFields);
  }

  void fromServerpodModel(TServerpodModel model) {
    final dynamic dynamicModel = model;
    final dynamic json = dynamicModel.toJson();
    if (json is! Map<String, dynamic>) {
      throw ArgumentError('Serverpod model for $typeName must return Map<String, dynamic> from toJson()');
    }
    fromServerpodJson(json);
  }

  @override
  void fromServerpodJson(Map<String, dynamic> json) {
    fromJson(json);
  }
}
