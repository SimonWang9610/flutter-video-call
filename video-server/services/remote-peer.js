const kurento = require('kurento-client');

class RemotePeer {
    constructor(socket, pipeline, endpoint) {
        this.peerId = socket.userid;
        this.pipeline = pipeline;
        this.socket = socket;
        // the endpoint will send the media stream of [peerId] to connected endpoints
        this.endpoint = endpoint;
        // incoming endpoints will receive media streams from connected endpoints
        this.incomingEndpoints = {};
        this.incomingCandidates = {};
        this.incomingRecorders = {};
        this.recorder = null;
    }

    emit(event, data) {
        this.socket.emit(event, data);
    }

    broadcast(room, event, data) {
        this.socket.to(room).emit(event, data);
    }

    handleIceCandidateFound(incomingEndpoints, peerId) {

        let endpoint;
        let userid;

        if (incomingEndpoints && peerId) {
            endpoint = incomingEndpoints;
            userid = peerId;
        } else {
            endpoint = this.endpoint;
            userid = this.peerId;
        }

        endpoint.on('IceCandidateFound', (event) => {
            let candidate = kurento.getComplexType('IceCandidate')(event.candidate);
            this.emit('room:candidate', {
                userid: userid,
                candidate: {
                    candidate: candidate.candidate,
                    sdpMid: candidate.sdpMid,
                    sdpMLineIndex: candidate.sdpMLineIndex,
                }
            });
        });

        endpoint.on('MediaTranscodingStateChange', (event) => {
            let msg = event.state + ' for ' + userid;

            if (peerId) {
                msg = 'incoming media: ' + msg;
            }

            console.log(`################ ${msg}`);
        });
    }

    addIceCandidate(candidate, peerId) {
        if (peerId != this.peerId) {
            let incoming = this.incomingEndpoints[peerId];
            if (incoming) {
                incoming.addIceCandidate(candidate);
            } else {
                this.enqueueCandidate(peerId, candidate);
            }
        } else {
            this.endpoint.addIceCandidate(candidate);
        }
    }

    enqueueCandidate(peerId, candidate) {
        if (this.incomingCandidates[peerId]) {
            this.incomingCandidates[peerId].push(candidate);
        } else {
            this.incomingCandidates[peerId] = [];
        }
        // console.log(`enqueue ice candidate for remote peer ${peerId}`);
    }

    flushCandidates(peerId) {
        if (this.incomingCandidates[peerId]) {
            let queue = this.incomingCandidates[peerId];

            while (queue.length) {
                let candidate = queue.shift();
                this.incomingEndpoints[peerId].addIceCandidate(candidate);
            }
            console.log(`flush ice candidate for remote peer: ${peerId}`);
        }
    }

    async provide(remoteEndpoint) {
        await this.endpoint.connect(remoteEndpoint);
    }

    async getIncomingEndpoint(remotePeer) {
        let incoming = this.incomingEndpoints[remotePeer.peerId];
        let incomingRecorder;

        if (!incoming) {
            incoming = await this.pipeline.create('WebRtcEndpoint');
            // incomingRecorder = await this.pipeline.create('RecorderEndpoint', {
            //     uri: 'file:///tmp/video/incoming/' + this.peerId + '.mp4',
            //     mediaProfile: 'MP4',
            //     stopOnEndOfStream: true
            // });

            this.incomingEndpoints[remotePeer.peerId] = incoming;
            //this.incomingRecorders[remotePeer.peerId] = incomingRecorder;
            this.flushCandidates(remotePeer.peerId);
        }
        console.log(`${this.peerId} request incoming endpoint from ${remotePeer.peerId}`);
        // enable incoming endpoint to receive video from [userid]
        await remotePeer.endpoint.connect(incoming);
        //await incoming.connect(incomingRecorder);

        console.log(`${this.peerId} of incoming endpoint connected to remote media source`);
        return incoming;
    }

    async requestMediaFrom(remotePeer, sdpOffer) {
        let incoming = await this.getIncomingEndpoint(remotePeer);
        
        this.handleIceCandidateFound(incoming, remotePeer.peerId);

        let sdpAnswer = await incoming.processOffer(sdpOffer.sdp);
        
        this.emit('room:answer', {
            userid: remotePeer.peerId,
            answer: {
                sdp: sdpAnswer,
                type: 'answer',
            },
        });
        console.log(`incoming answer to ${this.peerId}`);
        incoming.gatherCandidates((error) => {
            if (error) {
            console.error(`error gathering candidate for ${remotePeer.peerId}: ${error}`);
            }
        });

        //this.startRecordingIncoming(remotePeer.peerId);
    }

    gatherCandidates() {
        this.endpoint.gatherCandidates((error) => {
            if (error) {
            console.error(`error on gathering candidate: ${error}`);
            }
        });
    }

    // TODO: should close endpoint if no need receiving from [userid]

    registerRecordHandler() {
        if (this.recorder) {
            this.recorder.record((err) => {
                if (err) {
                    console.log(`error on recording media for ${this.peerId}`);
                }
            });

            this.recorder.on('Recording', (event) => {
                console.log(`recording for ${this.peerId}`);
            });

            this.recorder.on('Stopped', (event) => {
                console.log(`stop recording for ${this.peerId}`);
            });

        }
    }

    startRecordingIncoming(peerId) {
        let recorder = this.incomingRecorders[peerId];

        if (recorder) {
            this.recorder.record((err) => {
                if (err) {
                    console.log(`error on recording media for ${this.peerId}`);
                }
            });

            this.recorder.on('Recording', (event) => {
                console.log(`************recording incoming media for ${this.peerId}`);
            });

            this.recorder.on('Stopped', (event) => {
                console.log(`**************stop recording incoming media for ${this.peerId}`);
            });
        }
    }

    async close() {
        await this.endpoint.release();

        if (this.recorder) {
            await this.recorder.stop();
        }

        for (let incoming of Object.values(this.incomingEndpoints)) {
            incoming.release();
        }
    }
}

module.exports = {
    RemotePeer,
}