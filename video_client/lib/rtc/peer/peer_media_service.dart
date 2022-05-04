import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_client/rtc/peer/peer_event.dart';

import 'package:video_client/rtc/peer/peer_helper.dart';
import 'package:video_client/rtc/peer/peer_service.dart';

import 'peer_base.dart';

class PeerMediaService extends PeerBase with PeerHelper {
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

  Map<String, dynamic> get sendOnlyConstraints => {
        'mandatory': {
          'offerToReceiveAudio': false,
          'offerToReceiveVideo': false,
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

  PeerMediaService({
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

    print('start service***************************${DateTime.now()}');
    initRoom();
  }

  void initRoom() async {
    rtcService.connectRTCService(
      userid: config.currentUserId,
      username: config.currentUserName,
    );

    if (type == 'video') {
      await localRender!.initialize();
    }

    await joinRoom();
  }

  Future<void> joinRoom() async {
    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    if (type == 'video') {
      localRender!.srcObject = localStream;
    }

    controller.add(
      PeerEvent(
        canLocalPreview: true,
      ),
    );

    final sdpOffer = await generateOffer(config.currentUserId);

    rtcService.emitRTCEvent('room:join', {
      'room': room,
      'sdpOffer': sdpOffer.toMap(),
      'members': config.isCaller ? [config.caller, config.callee] : null,
      'caller': config.isCaller ? config.currentUserId : null,
      'type': type,
    });

    listenRtcEvent();
  }

  Future<RTCSessionDescription> generateOffer(String peerId,
      [bool sendOnly = true]) async {
    if (!peerConnections.containsKey(peerId)) {
      await connectPeer(peerId);
    }

    final peerConn = peerConnections[peerId]!;

    if (type == 'video') {
      print('add video tracks');
      localStream!.getTracks().forEach(
            (track) => peerConn.addTrack(
              track,
              localStream!,
            ),
          );
    } else if (type == 'audio') {
      localStream!.getAudioTracks().forEach(
            (track) => peerConn.addTrack(track, localStream!),
          );
    }

    peerConn.onTrack ??= (event) => onTrack(peerId, event);
    peerConn.onAddTrack ??=
        (stream, track) => onAddTrack(peerId, stream, track);

    peerConn.onRemoveTrack ??=
        (stream, track) => onRemoveTrack(peerId, stream, track);

    // if (candidatesQueue.isNotEmpty) {
    //   for (final candidate in candidatesQueue) {
    //     rtcService.emitRTCEvent('room:candidate', {
    //       'room': room,
    //       'candidate': candidate.toMap(),
    //       'peerId': peerId,
    //     });
    //   }
    // }

    // TODO: apply [recveOnlyConstraints]
    final sdpOffer = await peerConn
        .createOffer(sendOnly ? sendOnlyConstraints : offerSdpConstraints);
    await peerConn.setLocalDescription(sdpOffer);

    return sdpOffer;
  }

  Future<void> connectPeer(String peerId) async {
    if (kDebugMode) {
      print('connecting to $peerId');
    }

    final peerConnection = await createPeerConnection(configuration);

    // only need to create render for incoming media stream
    if (peerId != config.currentUserId) {
      final peerRender = RTCVideoRenderer();

      await peerRender.initialize();
      remoteRenders[peerId] = peerRender;
    }

    peerConnections[peerId] = peerConnection;

    peerConnection.onSignalingState = onHandshakeState<RTCSignalingState>;
    peerConnection.onIceGatheringState = onHandshakeState<RTCIceGatheringState>;

    peerConnection.onIceConnectionState =
        (state) => onIceConnectionState(peerId, state);

    peerConnection.onConnectionState =
        (state) => onPeerConnectionState(peerId, state);

    peerConnection.onIceCandidate =
        (candidate) => onIceCandidate(peerId, candidate);

    peerConnection.onRenegotiationNeeded = () => onRenegotiationNeeded(peerId);
  }

  Future<void> requestMediaFrom(
    String peerId, {
    bool willSendMedia = false,
    bool sendOnly = false,
  }) async {
    final sdpOffer = await generateOffer(peerId, sendOnly);

    print('OFFER to: $peerId');
    print('----------------$sdpOffer');

    rtcService.emitRTCEvent('room:media:request', {
      'room': room,
      'peerId': peerId,
      'sdpOffer': sdpOffer.toMap(),
      'who': config.currentUserId,
    });

    if (willSendMedia) {
      rtcService.emitRTCEvent('room:media:send', {
        'room': room,
        'peerId': peerId,
        'who': config.currentUserId,
      });
    }
  }

  void listenRtcEvent() {
    // receive: room:joined
    // send: room:media:request
    // also will send local media: room:media:send
    rtcService.onRTCEvent('room:joined', (data) {
      final res = data as Map<String, dynamic>;
      // someone joins the room
      // current user needs to request media from [userid]
      // also tell [userid] to request media from self
      requestMediaFrom(
        res['userid'],
        willSendMedia: true,
        sendOnly: false,
      );
      print('JOINED: ${res['userid']}  ');
    });

    // receive: room:answer
    // successfully connected
    rtcService.onRTCEvent('room:answer', (data) async {
      final res = data as Map<String, dynamic>;
      final peerId = res['userid'];
      final answer = res['answer'];

      final sdpAnswer = RTCSessionDescription(answer['sdp'], answer['type']);

      await setRemoteSDP(peerId, sdpAnswer);

      print('ANSWER from $peerId');
      print('--------------- $answer');

      if (peerId != config.currentUserId) {
        controller.add(PeerEvent(
          isCalling: false,
          canLocalPreview: true,
        ));
      }
    });

    rtcService.onRTCEvent('room:media:send', (data) {
      final res = data as Map<String, dynamic>;
      final sender = res['sender'];
      // [sender] tells current user to request media from [sender]
      requestMediaFrom(sender, sendOnly: false);
      print('SEND MEDIA: $sender');
    });

    rtcService.onRTCEvent('room:candidate', onAddIceCandidate);

    rtcService.onRTCEvent('room:leave', (data) {
      // final res = data as Map<String, dynamic>;

      // final who = res['userid'];
      // final remain = res['remain'] as int;
      // handlePeerLeave(who, remain);
    });
  }

  void handlePeerLeave(String peerId, int remain) async {
    if (remain <= 1) {
      close();
    } else {
      await peerConnections[peerId]?.close();
      await remoteRenders[peerId]?.dispose();
      peerConnections.remove(peerId);
      remoteRenders.remove(peerId);
    }
  }
}
