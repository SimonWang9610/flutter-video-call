const mainIO = require('./main-io-handler');
const {RemotePeer} = require('./remote-peer');

// clients, especially for the room creator, 
// may send IceCandidate before creating the room
// so we have to maintain the globalQueue for such special cases
const globalQueue = {};

class Room {
    constructor(id, pipeline) {
        // IceCandidate
        this.id = id;
        this.queue = {};
        this.pipeline = pipeline;
        this.peers = {};
    }

    emitTo(userid, event, data) {
        if (!this.peers[userid]) return;

        this.peers[userid].emit(event, data);
    }

    broadcastFrom(userid, event, data) {
        this.peers[userid].broadcast(this.id, event, data);
    }

    async register(socket, endpoint, recorder) {

        let peer = new RemotePeer(socket, this.pipeline, endpoint);
        
        if (recorder) {
            peer.recorder = recorder;
        }

        this.peers[socket.userid] = peer;

        let candidateQueue = this.queue[socket.userid];

        // if (candidateQueue) {

        //     while (candidateQueue.length) {
        //         let [candidate, peerId] = candidateQueue.shift();
        //         peer.addIceCandidate(candidate, peerId);
        //     }
        //     console.log(`flush ica candidate queue of ${socket.userid}`);
        // }

        this.flushCandidateQueue(socket.userid);

        await endpoint.connect(recorder);
        peer.registerRecordHandler();
    }

    flushCandidateQueue(userid) {

        let queue;

         if (globalQueue[userid]) {
            queue = globalQueue[userid];
         }

         if (this.queue[userid]) {
             queue = queue ? queue.concat(this.queue[userid]): this.queue[userid];
         }

        if (queue) {
            while (queue.length) {
                let [candidate, peerId] = queue.shift();
                this.peers[userid].addIceCandidate(candidate, peerId);
            }

            console.log(`-----------flush ice candidate queue of ${userid}`);
        }
    }

    async createAnswer(userid, sdpOffer)  {
        if (this.peers[userid]) {
            let newPeer = this.peers[userid];

            newPeer.handleIceCandidateFound();

            // enable [userid] to receive media from other peers
            // for (let peer of Object.values(this.peers)) {
            //     if (peer.peerId !== userid) {
            //         await this.connect(peer, newPeer);
            //     }
            // }
    
            let sdpAnswer = await newPeer.endpoint.processOffer(sdpOffer.sdp);

            console.log(`answer to ${userid}`);
    
            this.emitTo(userid, 'room:answer', {
                userid: userid,
                answer: {
                    sdp: sdpAnswer,
                    type: 'answer',
                },
            });

            newPeer.gatherCandidates();
            
        } else {
            console.log(`${userid} has not register yet`);
        }
    }

    addOrEnqueue(userid, candidate, peerId) {
        if (this.peers[userid]) {
            // console.log(`add ice candidate for ${userid}`);

            this.peers[userid].addIceCandidate(candidate, peerId);
        } else {
            // console.log(`enqueue ice candidate for ${userid}`);
            
            if (this.queue[userid]) {
                this.queue[userid].push([candidate, peerId]);
            } else {
                this.queue[userid] = [];
            }
        }
    }

    async leave(userid) {

        if (!this.peers[userid]) {
            return;
        }

        this.broadcastFrom(userid, 'room:leave', {
            userid: userid,
            remain: this.peers.length - 1,
        });
        // TODO: should disconnect all its incomingEndpoints
        this.peers[userid].socket.leave(this.id);
        await this.peers[userid].close();

        delete this.peers[userid];

    }

    invite(members, type, caller) {
        for (let member of members) {

            if (member !== caller) {
                mainIO.emitTo(member, 'room:invite', {
                    room: this.id,
                    type: type,
                    caller: caller,
                    callee: member,
                });
            }
        }
    }

    joined(userid) {
        this.broadcastFrom(userid, 'room:joined', {
            userid: userid
        });
    }

    async connect(mediaProvider, mediaReceiver) {
        await mediaProvider.provide(mediaReceiver.endpoint);
    }

    close() {
        this.pipeline.release();

        for (let peer of this.peers) {
            peer.emit('room:close', {
                message: 'room closed'
            });
        }
    }

    getPeer(userid) {
        return this.peers[userid]
    }
}



module.exports = {
    Room,
    globalQueue,
}