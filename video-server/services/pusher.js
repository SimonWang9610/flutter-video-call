
const clients = new Map();


module.exports.getOnlineUser = (userid) => clients.get(userid);

module.exports.processWebSocket = (ws, userid) => {
    console.log(`A new WebSocket created: ${JSON.stringify(ws._socket._peername)}`);


    for (let client of clients.values()) {
        console.log('broadcast to client');
        broadcastContact(client, userid)
    }

    for (let client of clients.keys()) {
        const msg = {
            'topic': 'contact',
            'contact': client
        }

        ws.send(JSON.stringify(msg))
    }

    clients.set(userid, ws)

    ws.on('message', (msg) => {
        console.log(`ws message: ${JSON.stringify(msg)}`);
    })

    ws.on('close', () => {
        console.log('ws closed');
    })
}

module.exports.sendMessage = (userid, payload) => {
    const ws = clients.get(userid);

    if (ws) {
        ws.send(JSON.stringify(payload))
    }
}

function broadcastContact(ws, userid) {
    const msg = {
        'topic': 'contact',
        'contact': userid
    }

    ws.send(JSON.stringify(msg))
}