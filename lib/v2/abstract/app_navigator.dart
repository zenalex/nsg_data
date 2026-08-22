import 'dart:async';

/// AppNavigator is a navigator for the app. It's responsible for navigating between the app's pages.
abstract interface class AppNavigator {
  /// Push a new page onto the stack.
  FutureOr<void> push(String routeName);

  /// Pop the current page off the stack.
  FutureOr<void> pop();

  /// Go to a new page.
  FutureOr<void> go(String routeName);

  /// Clear the stack and go to the root page.
  FutureOr<void> clear();
}
