import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/riverpod/core/repository/nsg_entity_repository.dart';

typedef NsgRepositoryProvider<T extends NsgDataItem> =
    ProviderListenable<NsgEntityRepository<T>>;
