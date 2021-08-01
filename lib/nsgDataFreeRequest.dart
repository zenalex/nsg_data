import 'package:nsg_data/nsg_data_provider.dart';
import 'package:nsg_data/nsg_data_requestParams.dart';

class NsgDataFreeRequest {
  static Future<dynamic> requestData({
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String? tag,
    String function = '',
    String method = 'GET',
    dynamic postData,
    required NsgDataProvider dataProvider,
  }) async {
    var filterMap = <String, String>{};
    if (filter != null) filterMap = filter.toJson();

    function = dataProvider.serverUri + function;
    var response = await dataProvider.baseRequestList(
        function: '$function',
        headers: dataProvider.getAuthorizationHeader(),
        url: function,
        method: method,
        params: filterMap,
        postData: postData);

    return response;
  }
}
