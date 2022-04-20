module.exports = (socket, next) => {
    console.log('socket handshake');
    const userid = socket.handshake.auth.userid;
    const username = socket.handshake.auth.username;

    if (userid && username) {
        socket.userid = userid;
        socket.username = username;
        return next();
    } else {
        return next(new Error('invalid authentication fields'));
    }
}