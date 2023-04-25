import 'package:go_router/go_router.dart';
import 'package:nsg_data/nsg_data.dart';

class NsgRouter extends GoRouter {
  NsgRouter({
    required super.routes,
    super.errorPageBuilder,
    super.errorBuilder,
    super.redirect,
    super.refreshListenable,
    super.redirectLimit,
    super.routerNeglect,
    super.initialLocation,
    super.initialExtra,
    super.observers,
    super.debugLogDiagnostics,
    super.navigatorKey,
    super.restorationScopeId,
  });
}
