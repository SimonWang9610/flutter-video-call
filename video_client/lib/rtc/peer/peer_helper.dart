import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_client/rtc/peer/peer_base.dart';
import 'package:video_client/rtc/client_io.dart';

mixin PeerHelper on PeerBase {
  void onTrack(String peerId, RTCTrackEvent event) {
    remoteRenders[peerId]?.srcObject = event.streams[0];
  }

  void onAddTrack(String peerId, MediaStream stream, MediaStreamTrack track) {
    remoteRenders[peerId]?.srcObject = stream;
  }

  void onRemoveTrack(
      String peerId, MediaStream stream, MediaStreamTrack track) {
    remoteRenders[peerId]?.srcObject = null;
  }

  void onIceCandidate(String peerId, RTCIceCandidate candidate) {
    rtcService.emitRTCEvent('room:candidate', {
      'room': room,
      'candidate': candidate.toMap(),
    });
  }

  void onAddIceCandidate(dynamic data) {
    final peerData = data as Map<String, dynamic>;
    final peerId = peerData['userid'];
    final candidateMap = peerData['candidate'] as Map<String, dynamic>;

    peerConnections[peerId]?.addCandidate(
      candidateMap.asIceCandidate(),
    );
  }

  void onHandshakeState<T>(T state) {
    if (kDebugMode) {
      print(state);
    }
  }

  void onPeerConnectionState(String peerId, RTCPeerConnectionState state) {
    if (kDebugMode) {
      print('$peerId connection state: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {}
    }
  }

  void onRenegotiationNeeded(String peerId) {
    // TODO: handle re-negotitation and createAnswer()
  }

  void onPeerLeave(dynamic data) {
    final res = data as Map<String, dynamic>;

    if (res['userLeft'] < 2) {
      rtcService.leaveRoom();
    }
  }
}

extension IceCandidateFromMap on Map {
  RTCIceCandidate asIceCandidate() {
    return RTCIceCandidate(
      this['candidate'],
      this['sdpMid'],
      this['sdpMLineIndex'],
    );
  }
}
