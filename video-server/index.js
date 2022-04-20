const http = require('http')
const express = require('express')
const config = require('config')
const bodyParser = require('body-parser');
const uuid = require('uuid');

const videoRoute = require('./routes/video-route');

const ioAuth = require('./middlewares/io-auth');
const {handleMainIO} = require('./services/main-io-handler');
const {handleVideoIO} = require('./services/rtc-io-handler');

const app = express()
//const expressWs = require('express-ws')(app);
const httpServer = http.createServer(app)
const io = require('socket.io')(httpServer);

const rtcIO = io.of('/rtc');

app.use(bodyParser.urlencoded({extended: false, limit: '10mb'}));
// parse application/json
app.use(bodyParser.json({limit: '25mb'}));
// parse an HTML body into a string. The type defaults to text/plain
app.use(bodyParser.text());

app.use('/call', videoRoute)

// app.ws('/pusher/:userid', function(ws, req) {
//     const userid = req.params.userid;
//     console.log(`get socket connection: ${userid}`)

//     pusher.processWebSocket(ws, userid)
// });

app.get('/login', async (req, res, next) => {
    const userid = uuid.v4();

    res.status(200).json({
        userid: userid,
    });
})

app.post('/createRoom', async (req, res, next) => {
    console.log(`rtc room type: ${req.body.type}`);
    const room = uuid.v4();

    res.status(200).json({
        room: room,
        type: req.body.type,
    });
})

io.use(ioAuth);
rtcIO.use(ioAuth);

io.on('connection', handleMainIO);

rtcIO.on('connection', handleVideoIO);

httpServer.listen(config.http.port, (err) => {
    if (err) {
        console.log(err)
    } else {
        console.log(`Server listing on ${config.http.port}`)
    }
})