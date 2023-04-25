import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nsg_data/nsg_data.dart';

import 'nsg_binding.dart';

class NsgRoute extends GoRoute {
  final NsgBinding? binding;
  final GoRouterWidgetBuilder page;

  NsgRoute({
    required super.path,
    this.binding,
    super.name,
    required this.page,
    super.pageBuilder,
    super.parentNavigatorKey,
    super.redirect,
    super.routes = const <RouteBase>[],
  }) : super(builder: (context, state) => page(context, state));

  @override
  GoRouterPageBuilder? get pageBuilder {
    var pb = super.pageBuilder;
    if (binding != null) {
      binding!.dependencies();
    }
    return pb;
  }

  static Widget buildPage(BuildContext context, GoRouterState state, NsgRoute route) {
    return route.page(context, state);
  }
}
