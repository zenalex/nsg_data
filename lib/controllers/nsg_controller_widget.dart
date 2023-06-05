import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it_mixin/get_it_mixin.dart';
import 'package:nsg_data/controllers/nsgBaseController.dart';

import 'nsg_controller_status.dart';
import 'nsg_update_key.dart';

class NsgControllerWidget extends StatelessWidget with GetItMixin {
  final NsgBaseController controller;
  final NsgWidgetBuilder widget;
  final Widget Function(String? error)? onError;
  final Widget? onLoading;
  final Widget? onEmpty;
  final List<NsgUpdateKey>? keys;

  NsgControllerWidget(this.widget, {super.key, required this.controller, this.onError, this.onLoading, this.onEmpty, this.keys});

  @override
  Widget build(BuildContext context) {
    var currentStatus = watch<ValueListenable<NsgControillerStatus>, NsgControillerStatus>(target: controller.currentStautsListenable);
    if (currentStatus == NsgControillerStatus.loading) {
      return onLoading ?? NsgBaseController.getDefaultProgressIndicator();
    } else if (currentStatus == NsgControillerStatus.error) {
      return onError != null ? onError!(controller.errorDescription) : Center(child: Text('A error occurred: ${controller.errorDescription}'));
    } else if (currentStatus == NsgControillerStatus.empty) {
      return onEmpty ?? const SizedBox.shrink();
    }
    return widget('');
  }
}
