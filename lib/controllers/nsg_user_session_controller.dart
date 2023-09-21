// ignore_for_file: file_names

import 'package:nsg_data/nsg_data.dart';

class NsgUserSessionController extends NsgDataController<NsgUserSession> {
  NsgDataProvider? provider;
  NsgUserSessionController({
    super.requestOnInit = true,
    super.masterController,
    super.dataBindign,
    super.autoRepeate = false,
    super.autoRepeateCount = 10,
    super.useDataCache = false,
    super.selectedMasterRequired = true,
    super.autoSelectFirstItem = false,
    super.dependsOnControllers,
  });

  Future<bool?> endUserSession(String sessionId,
      {NsgDataRequestParams? filter, bool showProgress = false, bool isStoppable = false, String? textDialog}) async {
    var params = <String, dynamic>{};
    params['sessionId'] = sessionId;
    filter ??= NsgDataRequestParams();
    filter.params?.addAll(params);
    filter.params ??= params;
    var res = await NsgSimpleRequest<bool>().requestItem(
      provider: provider!,
      function: '/Api/Auth/EndUserSession',
      method: 'POST',
      filter: filter,
      autoRepeate: true,
      autoRepeateCount: 3,
    );
    return res;
  }
}
