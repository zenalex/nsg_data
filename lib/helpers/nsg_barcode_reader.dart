import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//Callback function signature
typedef BarcodeScannedCallback = void Function(String barcode);

/// Class to Listen for PHYSICAL keyboard keys pressed in
/// short amount of time ending in newline making it easy
/// to implement most of the barcode reader devices
/// This widget will listen for raw PHYSICAL keyboard events
/// even when other controls have primary focus.
/// It will buffer all characters coming in specifed `bufferDuration` time frame
/// that end with line feed character and call callback function with result.
/// Keep in mind this widget will listen for events even when not visible.
/// Windows seems to be using the [RawKeyDownEvent] instead of the
/// [RawKeyUpEvent], this behaviour can be managed by setting [useKeyDownEvent].
class NsgBarcodeListener extends StatefulWidget {
  /// Child widget to be displayed.
  final Widget child;

  /// Callback to be called when barcode is scanned.
  final BarcodeScannedCallback _onBarcodeScanned;

  /// Maximum time between two key events.
  /// If time between two key events is longer than this value
  /// previous keys will be ignored.
  final Duration _bufferDuration;

  /// When experiencing issueswith empty barcodes on Windows,
  /// set this value to true. Default value is `false`.
  final bool useKeyDownEvent;

  /// Make barcode scanner return case sensitive characters
  ///
  /// Default value is false, It will sent scanned barcode with case sensitive
  /// characters. It listen to [LogicalKeyboardKey.shiftLeft]
  /// Currently support for Android
  final bool caseSensitive;

  /// This widget will listen for raw PHYSICAL keyboard events
  /// even when other controls have primary focus.
  /// It will buffer all characters coming in specifed `bufferDuration` time frame
  /// that end with line feed character and call callback function with result.
  /// Keep in mind this widget will listen for events even when not visible.
  const NsgBarcodeListener({
    Key? key,

    /// Child widget to be displayed.
    required this.child,

    /// Callback to be called when barcode is scanned.
    required Function(String) onBarcodeScanned,

    /// When experiencing issueswith empty barcodes on Windows,
    /// set this value to true. Default value is `false`.
    this.useKeyDownEvent = false,

    /// Maximum time between two key events.
    /// If time between two key events is longer than this value
    /// previous keys will be ignored.
    Duration bufferDuration = hundredMs,
    this.caseSensitive = false,
  })  : _onBarcodeScanned = onBarcodeScanned,
        _bufferDuration = bufferDuration,
        super(key: key);

  @override
  // ignore: no_logic_in_create_state
  NsgBarcodeListenerState createState() => NsgBarcodeListenerState(_onBarcodeScanned, _bufferDuration, useKeyDownEvent);
}

//One Second constant
const Duration aSecond = Duration(seconds: 1);
//100 miliseconds constant
const Duration hundredMs = Duration(milliseconds: 100);
//lineFeed character constant
const String lineFeed = 'Enter';

class NsgBarcodeListenerState extends State<NsgBarcodeListener> {
  List<String> _scannedChars = [];
  DateTime? _lastScannedCharCodeTime;
  late StreamSubscription<String?> _keyboardSubscription;

  final BarcodeScannedCallback _onBarcodeScannedCallback;
  final Duration _bufferDuration;

  final _controller = StreamController<String?>();

  final bool _useKeyDownEvent;

  NsgBarcodeListenerState(this._onBarcodeScannedCallback, this._bufferDuration, this._useKeyDownEvent) {
    HardwareKeyboard.instance.addHandler(_keyBoardCallback);
    _keyboardSubscription = _controller.stream.where((char) => char != null).listen(onKeyEvent);
  }

  void onKeyEvent(String? char) {
    //remove any pending characters older than bufferDuration value
    checkPendingCharCodesToClear();
    _lastScannedCharCodeTime = DateTime.now();
    if (char == lineFeed) {
      _onBarcodeScannedCallback.call(_scannedChars.join());
      resetScannedCharCodes();
    } else {
      //add character to list of scanned characters;
      _scannedChars.add(char!);
    }
  }

  void checkPendingCharCodesToClear() {
    if (_lastScannedCharCodeTime != null) {
      if (_lastScannedCharCodeTime!.isBefore(DateTime.now().subtract(_bufferDuration))) {
        resetScannedCharCodes();
      }
    }
  }

  void resetScannedCharCodes() {
    _lastScannedCharCodeTime = null;
    _scannedChars = [];
  }

  void addScannedCharCode(String charCode) {
    _scannedChars.add(charCode);
  }

  bool _keyBoardCallback(KeyEvent keyEvent) {
    if (keyEvent.logicalKey.keyId > 255 && keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.shiftLeft) return false;
    if ((!_useKeyDownEvent && keyEvent is KeyUpEvent) || (_useKeyDownEvent && keyEvent is KeyDownEvent)) {
      _controller.sink.add(keyEvent.logicalKey.keyLabel);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _keyboardSubscription.cancel();
    _controller.close();
    super.dispose();
  }
}
