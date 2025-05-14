import 'package:get/get.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/ui/nsg_loading_scroll_controller.dart';

mixin NsgDataUI<T extends NsgDataItem> on NsgDataController<T> {
  int loadStepCountUi = 25;

  Future<List<T>> _loadItems(int top, int count) async {
    var matches = NsgDataRequest<T>(dataItemType: T);
    var filter = getRequestFilter;
    filter.top = top;
    filter.count = count;
    List<T> ans = await matches.requestItems(filter: filter, loadReference: referenceList);
    return ans;
  }

  @override
  NsgDataRequestParams get getRequestFilter {
    var filter = super.getRequestFilter;
    filter.count = loadStepCountUi;
    return filter;
  }

  Future loadNext() async {
    status = GetStatus.loading();
    sendNotify();
    if (items.length + 1 < (totalCount ?? 1000)) {
      items.addAll(await _loadItems(items.length + 1, loadStepCountUi));
    }
    status = GetStatus.success(NsgBaseController.emptyData);
    sendNotify();
  }

  late NsgLoadingScrollController scrollController = NsgLoadingScrollController(
    function: () async {
      await loadNext();
    },
  );
}
