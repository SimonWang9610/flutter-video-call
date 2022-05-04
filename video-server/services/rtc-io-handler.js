const mediaHandler = require('./rtc-media-handler');

module.exports.handleVideoIO = (socket) => {

    socket.on('room:join', (data) => mediaHandler.joinRoom(socket, data));
    socket.on('room:candidate', (data) => mediaHandler.onIceCandidate(socket.userid, data));
    socket.on('room:leave', mediaHandler.leaveRoom);
    socket.on('room:close', mediaHandler.closeRoom);

    socket.on('room:reject', mediaHandler.reject);
    socket.on('room:media:request', mediaHandler.requestMediaFrom);
    socket.on('room:media:send', mediaHandler.sendMediaTo);
}
