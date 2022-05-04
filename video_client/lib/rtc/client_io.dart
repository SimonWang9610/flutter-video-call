import 'dart:async';
import 'rtc_media_screen.dart';
import 'contact_event.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef RTCCallHandler = void Function(Map<String, dynamic>);

class ClientIO {
  static final _instance = ClientIO._();
  static const _baseUri = 'http://149.248.51.194:8888/';

  ClientIO._();

  factory ClientIO() => _instance;

  IO.Socket? _main;
  StreamController<ContactEvent>? _mainController;

  IO.Socket? _rtc;

  BuildContext? rootContext;
  BuildContext? rtcContext;

  init(String userid, String username) {
    print('init ClientIO');
    _mainController = StreamController();

    final opts = IO.OptionBuilder().setAuth({
      'userid': userid,
      'username': username,
    }).setTransports(['websocket']).build();

    _main = IO.io(_baseUri, opts);

    registerMainIoEventHandler();
  }

  Stream<ContactEvent> watchMain() => _mainController!.stream;

  void connectRTCService({
    required String userid,
    required String username,
    String namespace = 'rtc',
  }) {
    final opts = IO.OptionBuilder().setAuth({
      'userid': userid,
      'username': username,
    }).setTransports(['websocket']).build();

    _rtc = IO.io(_baseUri + namespace, opts);
    print('connected to /rtc');
  }

  void close() {
    _rtc?.close();
  }

  void emitRTCEvent(String event, Map<String, dynamic> data) {
    _rtc!.emit(event, data);
  }

  void onRTCEvent(String event, void Function(dynamic) handler) {
    _rtc!.on(event, handler);
  }
}

extension MainIOEventHandler on ClientIO {
  void registerMainIoEventHandler() {
    _main!.on('contact:online', (data) {
      final res = data as Map<String, dynamic>;

      _mainController?.add(
        ContactEvent(
          userid: res['userid'],
          username: res['username'],
        ),
      );
    });

    _main!.on('contact:offline', (data) {
      final res = data as Map<String, dynamic>;

      _mainController?.add(
        ContactEvent(
          userid: res['userid'],
          username: res['username'],
          online: false,
        ),
      );
    });

    _main!.on('room:invite', (data) {
      final res = data as Map<String, dynamic>;
      handleCalling(data);
    });

    _main!.on('room:noresponse', (_) => leaveRoom());

    _main!.on('rtc:reject', (_) => leaveRoom());

    _main!.on('room:leave', (_) => leaveRoom());
  }

  void leaveRoom() {
    Navigator.of(rtcContext!).pop();
    rtcContext = null;
  }
}

extension RemoteRTCEventHandler on ClientIO {
  void handleCalling(Map<String, dynamic> data) {
    print('remote calling: $data');
    final caller = data['caller'];
    final callee = data['callee'];
    final room = data['room'];
    final type = data['type'];

    showDialog(
      barrierDismissible: false,
      context: rootContext!,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Calling from $caller'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => reject(
              context,
              callee: callee,
              caller: caller,
            ),
            child: const Icon(
              Icons.phone_callback,
              color: Colors.redAccent,
            ),
          ),
          TextButton(
            onPressed: () => accept(
              context,
              callee: callee,
              caller: caller,
              room: room,
              type: type,
            ),
            child: const Icon(
              Icons.phone_in_talk,
              color: Colors.greenAccent,
            ),
          )
        ],
      ),
    );
  }

  void accept(
    BuildContext context, {
    required String caller,
    required String callee,
    required String room,
    required String type,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RTCVideo(
          room: room,
          callee: callee,
          caller: caller,
          isCaller: false,
          type: type,
        ),
      ),
    );
  }

  void reject(
    BuildContext context, {
    required String caller,
    required String callee,
  }) {
    Navigator.of(context).pop();

    _main!.emit('rtc:reject', {
      'caller': caller,
      'callee': callee,
    });
  }
}
