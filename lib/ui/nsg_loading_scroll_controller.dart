import 'package:flutter/material.dart';
import 'package:nsg_data/ui/nsg_data_ui.dart';

class NsgLoadingScrollController<T> extends ScrollController {
  NsgLoadingScrollController({this.function, this.positionBeforeLoad = 200, this.attemptCount = 1}) : super(keepScrollOffset: true) {
    addListener(() async {
      try {
        if (_attCount < attemptCount &&
            _stat != NsgLoadingScrollStatus.loading &&
            _stat != NsgLoadingScrollStatus.pause &&
            positions.isNotEmpty &&
            (position.pixels >= position.maxScrollExtent - positionBeforeLoad)) {
          _stat = NsgLoadingScrollStatus.loading;
          try {
            _attCount++;
            if (function != null) {
              Future(function!).then((T val) {
                _value = val;
                _stat = NsgLoadingScrollStatus.success;
              });
            } else {
              _stat = NsgLoadingScrollStatus.empty;
            }
          } catch (er) {
            _errCount++;
            if (_errCount > 3) {
              _stat = NsgLoadingScrollStatus.error;
            }
          }
        } else if (!(positions.isNotEmpty && position.pixels >= position.maxScrollExtent - positionBeforeLoad)) {
          _attCount = 0;
          _errCount = 0;
        }

        lastOffset = offset;
      } catch (e) {
        // Handle cases where ScrollController is not properly attached
        // or has multiple positions
      }
    });
  }

  final T Function()? function;
  final double positionBeforeLoad;
  final int attemptCount;

  double lastOffset = 0;

  //Map<int, double> heightMap = {};
  DataGroupList dataGroups = DataGroupList([]);

  int _errCount = 0;
  int _attCount = 0;

  T? _value;

  T? get value => _value;
  set value(T? val) {
    value = val;
    statusChange.notifyListeners();
    notifyListeners();
  }

  String? error;
  NsgLoadingScrollStatus _status = NsgLoadingScrollStatus.init;
  set _stat(NsgLoadingScrollStatus value) {
    _status = value;
    statusChange.notifyListeners();
    notifyListeners();
  }

  NsgLoadingScrollStatus get _stat => _status;

  NsgLoadingScrollStatus get status => _status;

  stopUpdate() {
    _status = NsgLoadingScrollStatus.pause;
  }

  startUpdate() {
    _errCount = 0;
    _attCount = 0;
    _status = NsgLoadingScrollStatus.init;
  }

  // void scrollToIndex(int index) {
  //   double position = 0;
  //   for (int i = 0; i < index; i++) {
  //     position += heightMap[i] ?? 0;
  //   }
  //   animateTo(
  //     position,
  //     duration: const Duration(milliseconds: 300),
  //     curve: Curves.easeInOut,
  //   );
  // }

  Future<void> scrollToIndex(int targetIndex) async {
    if (targetIndex == -1) {
      return;
    }
    while (true) {
      final key = dataGroups.itemsKeys[targetIndex];
      if (key == null) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      final context = key.currentContext;
      if (context != null && context.mounted) {
        await Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 1), curve: Curves.easeInOut);
        break;
      } else {
        await animateTo(offset + 400, duration: const Duration(milliseconds: 1), curve: Curves.linear);
      }
      if (positions.isNotEmpty && position.pixels >= position.maxScrollExtent) {
        break;
      }
    }
  }

  double middleHeight(List<double> list, double delta) {
    if (list.isEmpty) return 0;

    final Map<double, int> counts = {};

    for (var item in list) {
      bool found = false;

      for (var key in counts.keys) {
        if ((item - key).abs() <= delta) {
          counts[key] = counts[key]! + 1;
          found = true;
          break;
        }
      }

      if (!found) {
        counts[item] = 1;
      }
    }

    int maxCount = counts.values.reduce((a, b) => a > b ? a : b);

    List<double> freqList = counts.entries.where((entry) => entry.value == maxCount).map((entry) => entry.key).toList();

    if (freqList.isEmpty) return 0;
    final sum = freqList.reduce((a, b) => a + b);
    return sum / freqList.length;
  }

  ChangeNotifier statusChange = ChangeNotifier();
}

enum NsgLoadingScrollStatus { loading, success, empty, pause, error, init }
