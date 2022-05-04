const kurento = require('kurento-client');
const config = require('config');
const {Room, globalQueue} = require('./room');

const rooms = {};

var kurentoClient = null;

module.exports.joinRoom = async (socket, data) => {

    // data = {
    //     required: room,
    //     required: sdpOffer,
    //     required: type,
    //     optional: members,
    //     optional: caller,
    // }

    console.log(`someone joins room, ${JSON.stringify(data)}`);

    try {
        if (!kurentoClient) {
            kurentoClient = await getKurentoClient(); 
        }
        console.log('connect to kurento client');
        let room = rooms[data.room];
    
        if (!room) {
            let pipeline = await kurentoClient.create('MediaPipeline');
            room = new Room(data.room, pipeline);
            rooms[data.room] = room;
            console.log(`create room: ${data.room}`);
        }
    
        let endpoint = await room.pipeline.create('WebRtcEndpoint');

        let recorder = await room.pipeline.create('RecorderEndpoint', {
            uri: 'file:///tmp/video/' + socket.userid + '.mp4',
            mediaProfile: 'MP4',
            stopOnEndOfStream: true
        });

        // register this peer
        await room.register(socket, endpoint, recorder);
        // create SDP answer for this peer
        await room.createAnswer(socket.userid, data.sdpOffer);

        socket.join(data.room);

        // invite others if this peer is the caller
        if (data.members && data.members.length) {
            room.invite(data.members, data.type, data.caller);
        } else {
            room.joined(socket.userid);
        }
    } catch (e) {
        console.error(`${e}`);
        throw e;
    }
}

module.exports.onIceCandidate = (userid, data) => {
    // console.log(`${userid} collect ice candidate on ${data.peerId}`);
    let candidate = kurento.getComplexType('IceCandidate')(data.candidate);

    if (rooms[data.room]) {
        rooms[data.room].addOrEnqueue(userid, candidate, data.peerId);
    } else {
        if (globalQueue[userid]) {
            globalQueue[userid].push([candidate, data.peerId]);
        } else {
            globalQueue[userid] = [];
        }
    }

}

module.exports.requestMediaFrom = (data) => {
    // [who] request media from [peerId]
    console.log(`${data.who} request media from ${data.peerId}`);
    let room = rooms[data.room];

    if (room) {
        let remotePeer = room.getPeer(data.peerId);
        let peer = room.getPeer(data.who);

        if (peer && remotePeer) {
            peer.requestMediaFrom(remotePeer, data.sdpOffer)
        }
    }
}

module.exports.sendMediaTo = ( data) => {
    console.log(`${data.who} want to send media to ${data.peerId}`);
    let room = rooms[data.room];
    // [who] want to send media to [peerId]
    if (room) {
        room.emitTo(data.peerId,'room:media:send', {sender: data.who});
    }
}

module.exports.closeRoom = (data) => {
    if (rooms[data.room]) {
        rooms[data.room].close();
    }

    delete rooms[data.room];
}

module.exports.leaveRoom = (data) => {
    console.log(`${data.userid} left room`);
    if (rooms[data.room]) {
        let room = rooms[data.room];
        room.leave(data.userid);

        // if (room.peers.length <= 1) {
        //     room.close();
        //     delete rooms[data.room]
        // }
    }
}

module.exports.reject = (data) => {
    //TODO: implement 
}

const getKurentoClient = () => {
    return new Promise((resolve, reject) => {
        console.log(`kurento server: ${config.kurento.url}`);
        kurento(config.kurento.url, (err, _client) => {
            console.log('connected to kurento server');
            if (err) {
                let msg = 'cannot find a media server at: ' + config.kurento.url + ' error: ' + err;
                reject(msg);
            }

            resolve(_client);
        })
    })
}

const prepareRecord = (endpoint, recorder) => {
    kurentoClient.connect()
}