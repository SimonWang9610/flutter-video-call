
## Video/Audio Call based on WebRTC

#### Supported
1. video call
2. audio call
3. mute audio
4. disable camera

### Client (Flutter App)
- use `flutter_webrtc` and `socket_io_client` for Dart

- each user has a unique `userid` bound with its socket
- set `username` but not used in this project

### Server (Express)

- user `socket.io`

### Support Kurento-Media-Server

#### problems
1. for some android devices not supporting h264 encode/decode, if not allowing VP8 in KMS, the remote SDP will have no available video codecs. for example, HUAWEI devices using KIRIN CPU and Google Pixel 6

2. even forcing KMS to only use h264 transcoding, sometimes calling between web/android/ios may fail because sometimes KMS actually does not transcoding or wrongly transcoding to different h264 profile?

3. (Flutter WebRtc) if the client-side does not `addTrack()` to the connections (even `recvonly`), we cannot start gathering `IceCandidate` and thus fail to create `PeerConnection`