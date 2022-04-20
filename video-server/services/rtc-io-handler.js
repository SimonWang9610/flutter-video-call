const mainIO = require('./main-io-handler');
const uuid = require('uuid');

const rooms = {};

const createRTCRoom = (socket, data) => {
    // the caller creates the room
    // then, invite the callee to join the room
    // data.room is the chatId for a group chat
    // for one to one chat, server will generate random roomId
    console.log(`create rtc room: ${JSON.stringify(data)}`);
    let room = data.room;

    if (!room) {
        room = uuid.v4();
    }

    const isOnline = mainIO.isOnline(data.callee);

    if (isOnline) {
        // the caller will join the room first
        socket.join(room);

        rooms[room] = 1;

        /* socket.to(data.callee).emit('room:invite', {
            caller: data.caller,
            callee: data.callee,
            room: room,room
        }) */
        console.log(`calling ${data.callee}`);

        mainIO.emitTo(data.callee, 'room:invite', {
            caller: data.caller,
            callee: data.callee,
            callerName: socket.username,
            room: room,
            type: data.type,
        });

    } else {
        // TODO: push video call notification to the callee
        // socket.emit('room:noresponse', {
        //     user: data.callee,
        //     message: 'user is offline'
        // });

        mainIO.emitTo(socket.userid, 'room:noresponse', {
            userid: data.callee,
            message: 'user is offline'
        });
    }
}

const joiningRoom = (socket, data) => {
    // exclude the caller/creator
    // each user will broadcast 'room:join' event to the room
    console.log(`${socket.userid} joining room ${data.room}`);
    socket.join(data.room);
    
    rooms[data.room] += 1

    socket.to(data.room).emit('room:joining', {
        userid: data.callee,
    });
}

const joinedRoom = (socket, data) => {

}

const leaveRoom = (socket, data) => {
    rooms[data.room] -= 1;

    console.log(`${socket.username} left room: ${data.room}`);
    console.log(`userLeft: ${rooms[data.room]}`);

    socket.to(data.room).emit('room:leave', {
        userid: socket.userid,
        message: 'user has left',
        userLeft: rooms[data.room]
    });
    
    socket.leave(data.room);
}

const sendPrivateMessage = (socket, data) => {
    socket.to(data.to).emit('room:private', data.message);
}

const offer = (socket, data) => {
    console.log(`offer from ${socket.username} in room ${data.room}`);
    socket.to(data.room).emit('room:offer', {
        userid: socket.userid,
        description: data.description,
    });
}

const answer = (socket, data) => {
    console.log(`answer from ${socket.username} in room ${data.room}`);

    socket.to(data.room).emit('room:answer', {
        userid: socket.userid,
        description: data.description,
    })
}

const icecandidate = (socket, data) => {
    console.log(`ice candidate: ${JSON.stringify(data)}`);
    socket.to(data.room).emit('room:candidate', {
        userid: socket.userid, 
        candidate: data.candidate,
    })
}

module.exports.handleVideoIO = (socket) => {
    console.log('connect to /video');
    socket.on('room:create', (data) => createRTCRoom(socket, data))

    socket.on('room:joining', (data) => joiningRoom(socket, data));

    socket.on('room:leave', (data) => leaveRoom(socket, data));

    // send private messages to [data.to]
    socket.on('room:private', (data) => sendPrivateMessage(socket, data));

    socket.on('room:offer', (data) => offer(socket, data));

    socket.on('room:answer', (data) => answer(socket, data));

    socket.on('room:candidate', (data) => icecandidate(socket, data))

    socket.on('room:joined', (data) => joinedRoom(socket, data));
}
