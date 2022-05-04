import 'dart:async';

import 'package:video_client/rtc/peer/peer_event.dart';
import 'package:video_client/rtc/peer/peer_service.dart';
import 'package:video_client/rtc/peer/peer_media_service.dart';
import 'package:video_client/rtc/rtc_view.dart';

import 'client_io.dart';
import '../utils/sotre_util.dart';
import 'video_calling.dart';
import 'package:flutter/material.dart';

class RTCVideo extends StatefulWidget {
  final String caller;
  final String callee;
  final String room;
  final String type;
  final bool isCaller;
  const RTCVideo({
    Key? key,
    required this.room,
    required this.callee,
    required this.caller,
    required this.isCaller,
    required this.type,
  }) : super(key: key);

  @override
  State<RTCVideo> createState() => _RTCVideoState();
}

class _RTCVideoState extends State<RTCVideo> {
  final String userid = LocalStorage.read('userid');
  final String username = LocalStorage.read('username');

  late final PeerMediaService _service;
  late final StreamSubscription<PeerEvent> _sub;

  bool _canPreview = false;
  bool _isCalling = true;

  @override
  void initState() {
    super.initState();

    ClientIO().rtcContext = context;

    print('rtc video: $userid, $username');

    final config = RTCConfig(
      callee: widget.callee,
      caller: widget.caller,
      currentUserId: userid,
      currentUserName: username,
      room: widget.room,
    );

    _service = PeerMediaService(
      config: config,
      type: widget.type,
    );

    _sub = _service.watchServiceEvent().listen(_handlePeerEvent);
  }

  void _handlePeerEvent(PeerEvent event) {
    _isCalling = event.isCalling;
    _canPreview = event.canLocalPreview;

    setState(() {});
  }

  @override
  void dispose() {
    _service.disconnect();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Video Call'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: _isCalling
                ? VideoCalling(
                    username: widget.isCaller ? widget.callee : widget.caller,
                  )
                : RTCView(
                    type: widget.type,
                    render: _service.getRemoteVideoRender(
                        widget.isCaller ? widget.callee : widget.caller),
                    canPreview: true,
                  ),
          ),
          if (_service.type == 'video')
            Positioned(
              right: 25,
              bottom: 40,
              child: RTCView(
                type: widget.type,
                render: _service.localRender!,
                canPreview: _canPreview,
                isMainView: false,
              ),
            ),
          Positioned(
            bottom: 20,
            child: Row(
              children: [
                if (_service.type == 'video')
                  IconButton(
                    onPressed: () => _service.toggleMedia('video'),
                    icon: const Icon(
                      Icons.camera_alt,
                    ),
                  ),
                const SizedBox(
                  width: 10,
                ),
                IconButton(
                  onPressed: _service.hangUp,
                  icon: const Icon(
                    Icons.phone_missed_outlined,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                IconButton(
                  onPressed: () => _service.toggleMedia('audio'),
                  icon: const Icon(Icons.mic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
