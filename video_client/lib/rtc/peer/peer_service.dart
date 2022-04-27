import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_client/rtc/peer/peer_event.dart';

import 'peer_base.dart';
import 'peer_helper.dart';

class PeerService extends PeerBase with PeerHelper {
  @override
  Map<String, dynamic> get mediaConstraints => {
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
      };

  @override
  Map<String, dynamic> get offerSdpConstraints => {
        'mandatory': {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        },
        'optional': [],
      };

  @override
  Map<String, dynamic> get configuration => {
        // open STUN/TURN server: https://openrelayproject.org/
        'iceServers': [
          // {
          //   'url': 'stun:stun.l.google.com:19302',
          // },
          {'url': 'stun:149.248.51.194:3478'},

          {
            'url': 'turn:149.248.51.194:3478',
            'username': 'simonwang',
            'credential': 'simonwang',
          }
        ],
        //'iceTransportPolicy': 'all',
        'sdpSemantics': 'unified-plan'
      };

  final String type;

  final RTCConfig config;

  PeerService({
    required this.config,
    this.type = 'video',
  }) : super(config.room) {
    if (kDebugMode) {
      print('peer service for $type');
    }

    audioEnabled = true;

    if (type == 'audio') {
      mediaConstraints['video'] = false;
      videoEnabled = false;
    }

    if (type == 'video') {
      localRender = RTCVideoRenderer();
    }

    initRTC();
  }

  void initRTC() async {
    rtcService.connectRTCService(
      userid: config.currentUserId,
      username: config.currentUserName,
    );

    if (type == 'video') {
      await localRender!.initialize();
    }

    await createRTCRoom();
  }

  Future<void> createRTCRoom() async {
    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    if (type == 'video') {
      localRender!.srcObject = localStream;
    }

    // notify the user can preview the local video
    controller.add(
      PeerEvent(
        canLocalPreview: true,
      ),
    );

    final eventData = {
      'caller': config.caller,
      'callee': config.callee,
      'room': room,
      'type': type,
    };

    if (config.isCaller) {
      rtcService.emitRTCEvent('room:create', eventData);
    } else {
      rtcService.emitRTCEvent('room:joining', eventData);
    }

    listenRTCHandShakeEvent();

    rtcService.onRTCEvent('room:candidate', onAddIceCandidate);
    rtcService.onRTCEvent('room:leave', onPeerLeave);
  }

  Future<void> startTrackingMedia(
    String peerId,
    String willSignalEvent, {
    RTCSessionDescription? sdp,
    bool willSignalAnswer = false,
  }) async {
    // create peer connection if the connection does not exist
    if (!peerConnections.containsKey(peerId)) {
      await connectPeer(peerId);
    }

    // create remote vide render
    // await createPeerVideoRender(peerId);

    // must set remote SDP if we will signal 'room:answer'
    // otherwise, we cannot createAnswer() for the connection
    if (sdp != null && willSignalAnswer) {
      await setRemoteSDP(peerId, sdp);
    }

    final peerConn = peerConnections[peerId]!;

    // push local stream to the remote peer
    if (enableDuplex || willSignalEvent == 'room:offer') {
      isOffer = true;

      if (type == 'video') {
        localStream!.getTracks().forEach(
              (track) => peerConn.addTrack(
                track,
                localStream!,
              ),
            );
      }

      if (type == 'audio') {
        localStream!.getAudioTracks().forEach(
              (track) => peerConn.addTrack(track, localStream!),
            );
      }
    }

    // track the remote stream from the remote peer
    if (enableDuplex || willSignalEvent == 'room:answer') {
      peerConn.onTrack ??= (event) => onTrack(peerId, event);
      peerConn.onAddTrack ??=
          (stream, track) => onAddTrack(peerId, stream, track);

      peerConn.onRemoveTrack ??=
          (stream, track) => onRemoveTrack(peerId, stream, track);
    }

    final localSdp = willSignalAnswer
        ? await peerConn.createAnswer()
        : await peerConn.createOffer(offerSdpConstraints);

    await peerConn.setLocalDescription(localSdp);

    if (kDebugMode) {
      // print('local SDP: ${localSdp.toMap()}');
    }

    rtcService.emitRTCEvent(
      willSignalEvent,
      {
        'room': room,
        'description': localSdp.toMap(),
      },
    );
  }

  Future<void> connectPeer(String peerId) async {
    if (kDebugMode) {
      print('connecting to $peerId');
    }

    final peerConnection = await createPeerConnection(configuration);

    final peerRender = RTCVideoRenderer();

    await peerRender.initialize();

    peerConnections[peerId] = peerConnection;
    remoteRenders[peerId] = peerRender;

    peerConnection.onSignalingState ??= onHandshakeState<RTCSignalingState>;
    peerConnection.onIceGatheringState ??=
        onHandshakeState<RTCIceGatheringState>;

    peerConnection.onIceConnectionState ??=
        (state) => onIceConnectionState(peerId, state);

    peerConnection.onConnectionState ??=
        (state) => onPeerConnectionState(peerId, state);

    peerConnection.onIceCandidate ??=
        (candidate) => onIceCandidate(peerId, candidate);

    peerConnection.onRenegotiationNeeded = () => onRenegotiationNeeded(peerId);
  }

  @override
  Future<void> reconnect(String peerId) async {
    if (isOffer) {
      await startTrackingMedia(peerId, 'room:offer');
    }
  }

  @override
  void signaling(String willSignalEvent, dynamic data) async {
    if (kDebugMode) {
      // print('Get signals data: $data ');
      print('Will signaling event: $willSignalEvent');
    }

    final signals = data as Map<String, dynamic>;
    final peerId = signals['userid'];

    if (willSignalEvent == 'room:offer') {
      await startTrackingMedia(peerId, willSignalEvent);
      return;
    }

    final description = signals['description'] as Map<String, dynamic>;

    final remoteSdp =
        RTCSessionDescription(description['sdp'], description['type']);

    if (willSignalEvent == 'room:joined') {
      await setRemoteSDP(peerId, remoteSdp);
      controller.add(
        PeerEvent(
          isCalling: false,
          canLocalPreview: true,
        ),
      );
      return;
    }

    if (willSignalEvent == 'room:answer') {
      await startTrackingMedia(
        peerId,
        willSignalEvent,
        sdp: remoteSdp,
        willSignalAnswer: true,
      );
      controller.add(
        PeerEvent(
          isCalling: false,
          canLocalPreview: true,
        ),
      );
      return;
    }
  }
}

class RTCConfig {
  final String caller;
  final String callee;
  final String currentUserId;
  final String currentUserName;
  final String room;
  late final bool isCaller;

  RTCConfig({
    required this.callee,
    required this.caller,
    required this.currentUserId,
    required this.currentUserName,
    required this.room,
  }) {
    isCaller = currentUserId == caller;
  }
}
