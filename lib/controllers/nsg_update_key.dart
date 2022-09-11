import 'package:nsg_data/nsg_data.dart';

class NsgUpdateKey {
  final NsgUpdateKeyType type;
  final String id;

  NsgUpdateKey({required this.id, required this.type});

  @override
  bool operator ==(Object other) => other is NsgUpdateKey && id == other.id;

  @override
  int get hashCode {
    return id.hashCode;
  }
}
