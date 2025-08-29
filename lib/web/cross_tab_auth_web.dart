import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Web implementation: sync short-lived auth token across tabs via BroadcastChannel
class CrossTabAuth {
  final String channelName;
  // Additional scope to disambiguate apps/environments (e.g., serverUri)
  final String scope;

  web.BroadcastChannel? _channel;
  JSFunction? _bcListener;
  JSFunction? _lsListener;

  String? _token;

  final void Function(String? token) onTokenChanged;
  final String? Function() getCurrentToken;

  CrossTabAuth({required this.channelName, required this.scope, required this.onTokenChanged, required this.getCurrentToken});

  static const _evSet = 'auth:set';
  static const _evReq = 'auth:req';
  static const _evLogout = 'auth:logout';

  late final String _lsKey = '__auth_broadcast__:$channelName';

  Future<void> init() async {
    try {
      _channel = web.BroadcastChannel(channelName);
      _bcListener = ((web.Event e) {
        final me = e as web.MessageEvent;
        final raw = _stringFromJsAny(me.data);
        if (raw != null && raw.isNotEmpty) {
          _handleMessageString(raw);
        }
      }).toJS;
      _channel!.addEventListener('message', _bcListener!);
    } catch (_) {
      _channel = null;
    }

    _lsListener = ((web.Event e) {
      final se = e as web.StorageEvent;
      final key = se.key;
      final newValue = se.newValue;
      if (key == _lsKey && newValue != null) {
        _handleMessageString(newValue);
      }
    }).toJS;
    web.window.addEventListener('storage', _lsListener!);
  }

  void dispose() {
    if (_bcListener != null) {
      _channel?.removeEventListener('message', _bcListener!);
      _bcListener = null;
    }
    if (_lsListener != null) {
      web.window.removeEventListener('storage', _lsListener!);
      _lsListener = null;
    }
    _channel?.close();
  }

  void requestTokenFromPeers() {
    _broadcast(_msg(type: _evReq, scope: scope));
  }

  void publishToken(String token) {
    _token = token;
    onTokenChanged(_token);
    _broadcast(_msg(type: _evSet, token: token, scope: scope));
  }

  void broadcastLogout() {
    _token = null;
    onTokenChanged(null);
    _broadcast(_msg(type: _evLogout, scope: scope));
  }

  void _handleMessageString(String raw) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'] as String?;
    final token = data['token'] as String?;
    final msgScope = data['scope'] as String?;

    // Ignore messages for a different app/server scope
    if (msgScope != scope) return;

    switch (type) {
      case _evReq:
        final mine = getCurrentToken();
        if (mine != null && mine.isNotEmpty) {
          _broadcast(_msg(type: _evSet, token: mine, scope: scope));
        }
        break;
      case _evSet:
        if (token != null && token.isNotEmpty) {
          _token = token;
          onTokenChanged(_token);
        }
        break;
      case _evLogout:
        _token = null;
        onTokenChanged(null);
        break;
    }
  }

  void _broadcast(String message) {
    if (_channel != null) {
      _channel!.postMessage(message.toJS);
    }
    web.window.localStorage.setItem(_lsKey, message);
    web.window.localStorage.removeItem(_lsKey);
  }

  static String _msg({required String type, String? token, String? scope}) =>
      jsonEncode({'type': type, if (token != null) 'token': token, if (scope != null) 'scope': scope});

  String? _stringFromJsAny(JSAny? any) {
    if (any == null) return null;
    try {
      // Expecting JSString because we only post strings
      return (any as JSString).toDart;
    } catch (_) {
      return null;
    }
  }
}
