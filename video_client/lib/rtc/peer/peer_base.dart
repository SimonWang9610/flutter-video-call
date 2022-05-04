import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_client/rtc/client_io.dart';
import 'package:video_client/rtc/peer/peer_event.dart';
import 'package:video_client/utils/sotre_util.dart';

abstract class PeerBase {
  Map<String, dynamic> get mediaConstraints;
  Map<String, dynamic> get offerSdpConstraints;
  Map<String, dynamic> get configuration;

  set mediaConstraints(Map<String, dynamic> value) => mediaConstraints = value;
  set offerSdpConstraints(Map<String, dynamic> value) =>
      offerSdpConstraints = value;
  set configuration(Map<String, dynamic> value) => configuration = value;

  final Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, RTCVideoRenderer> remoteRenders = {};
  final List<RTCIceCandidate> candidatesQueue = [];

  final ClientIO rtcService = ClientIO();
  final StreamController<PeerEvent> controller = StreamController();

  final String room;

  // render local video stream
  // for audio call, no need to initialize
  RTCVideoRenderer? localRender;

  // local audio/video stream
  MediaStream? localStream;

  // true: both sides will stream each other
  final bool enableDuplex;
  // the user will createOffer()
  late bool isOffer;

  late bool audioEnabled = true;
  late bool videoEnabled = true;

  RTCVideoRenderer getRemoteVideoRender(String peerId) =>
      remoteRenders[peerId]!;

  PeerBase(
    this.room, {
    this.enableDuplex = true,
  });

  Future<void> close() async {
    localRender?.dispose();

    localStream?.getTracks().forEach((track) => track.stop());

    await localStream?.dispose();

    for (final render in remoteRenders.values) {
      await render.dispose();
    }

    for (final conn in peerConnections.values) {
      await conn.close();
    }

    controller.close();
  }

  Future<void> reconnect(String peerId) {
    throw UnimplementedError('no implemented: reconnect');
  }

  void disconnect() => close();

  void signaling(String willSignalEvent, dynamic data) {
    throw UnimplementedError('no implement signaling');
  }

  void toggleMedia(String name) {
    final tracks = name == 'audio'
        ? localStream!.getAudioTracks()
        : localStream!.getVideoTracks();

    for (final track in tracks) {
      track.enabled = !track.enabled;
    }

    if (name == 'audio') {
      audioEnabled = !audioEnabled;
    } else {
      videoEnabled = !videoEnabled;
    }
  }

  Future<void> setRemoteSDP(String peerId, RTCSessionDescription sdp) async {
    peerConnections[peerId]!.setRemoteDescription(sdp);
  }

  void listenRTCHandShakeEvent() {
    rtcService.onRTCEvent(
      'room:joining',
      (data) => signaling('room:offer', data),
    );

    rtcService.onRTCEvent(
      'room:offer',
      (data) => signaling('room:answer', data),
    );

    rtcService.onRTCEvent(
      'room:answer',
      (data) => signaling('room:joined', data),
    );
  }

  Future<void> createPeerVideoRender(String peerId) async {
    final peerRender = RTCVideoRenderer();
    remoteRenders[peerId] = peerRender;
    await peerRender.initialize();
  }

  void hangUp() {
    rtcService.emitRTCEvent('room:leave', {
      'room': room,
      'userid': LocalStorage.read('userid'),
    });
    rtcService.leaveRoom();
  }

  Stream<PeerEvent> watchServiceEvent() => controller.stream;

  void switchCamera() async {
    throw UnimplementedError('waiting implement for switching camera');
  }

  void switchMic() async {
    throw UnimplementedError('waiting implement for switching microphone');
  }
}
