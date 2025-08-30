/// Stub implementation for non-web platforms: does nothing
class CrossTabAuth {
  final String channelName;
  final String scope;
  final void Function(String? token) onTokenChanged;
  final String? Function() getCurrentToken;

  CrossTabAuth({required this.channelName, required this.scope, required this.onTokenChanged, required this.getCurrentToken});

  Future<void> init() async {}
  void dispose() {}
  void requestTokenFromPeers() {}
  void publishToken(String token) {}
  void broadcastLogout() {}
}
