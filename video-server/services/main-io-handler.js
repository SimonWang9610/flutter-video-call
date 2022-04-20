
const clients = new Map();

module.exports.handleMainIO = (socket) =>  {
    
    console.log(`new socket io for ${socket.userid}`);

    for (const client of clients.values()) {
        socket.emit('contact:online', {
            userid: client.userid,
            username: client.username,
        })
    }

    clients.set(socket.userid, socket);

    for (const client of clients.entries()) {
        console.log(`user: ${client[0]}, socket: ${typeof client[1]}`);
    }

    socket.broadcast.emit('contact:online', {
        userid: socket.userid,
        username: socket.username,
    });

    
    socket.on('rtc:reject', (data) => {
        socket.to(data.caller).emit('rtc:reject');
    });

    socket.on('disconnect', (_) => {
        console.log(`${socket.userid} disconnect`);

        socket.broadcast.emit('contact:offline', {
            userid: socket.userid,
            username: socket.username,
        });

        clients.delete(socket.userid);
    })
}

module.exports.emitTo = (userid, event, data) => {

    const socket = clients.get(userid);
    if (socket) {
        console.log(`event: ${event} on ${userid}`);
        socket.emit(event, data);
    }
}

module.exports.isOnline = (userid) => {

    return clients.has(userid);
}