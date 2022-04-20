
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

