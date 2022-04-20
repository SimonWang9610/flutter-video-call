const express = require('express')
const config = require('config')
const pusher = require('../services/pusher')

const nanoid = require('nanoid')
const {RtcTokenBuilder, RtcRole} = require('agora-access-token')

const uidGen = nanoid.customAlphabet('123456789', 4)

const ROLE = RtcRole.PUBLISHER
const router = express.Router()

router.get('/createChannel', async (req, res, next) => {
    const uid = uidGen()
    const channel = nanoid.nanoid(32)
    const privilegeExpiry = Math.floor(Date.now() / 1000) + config.agora.expiry

    const token = RtcTokenBuilder.buildTokenWithUid(config.agora.appID, config.agora.appCert, channel, parseInt(uid), ROLE, privilegeExpiry)

    res.status(200).json({
        'token': token,
        'appId': config.agora.appID,
        'channel': channel,
        'uid': parseInt(uid), 
    })
});

router.post('/accountToken', async (req, res, next) => {
    console.log(`get request on token: ${JSON.stringify(req.body)}`)
    const account = req.body.account
    const channelName = req.body.channelName
    const privilegeExpiry = Math.floor(Date.now() / 1000) + config.agora.expiry
    console.log(`expiry: ${privilegeExpiry}`)
    const token = RtcTokenBuilder.buildTokenWithAccount(config.agora.appID, config.agora.appCert, channelName, account, ROLE, privilegeExpiry)
    console.log(`agora token: ${token}`)

    res.status(200).json({
        'token': token,
        'appId': config.agora.appID,
    });
});

router.post('/oneToOne', async (req, res, next) => {
    console.log('calling someone');
    const caller = req.body.caller;
    const callee = req.body.callee;

    const channel = req.body.channel;
    const agoraUid = uidGen();
    const privilegeExpiry = Math.floor(Date.now() / 1000) + config.agora.expiry

    const token = RtcTokenBuilder.buildTokenWithUid(config.agora.appID, config.agora.appCert, channel, parseInt(agoraUid), ROLE, privilegeExpiry)

    // push payload to remote server
    const payload = {
        'topic': 'videoCall',
        'caller': caller,
        'callee': callee,
        'channel': channel,
        'uid': parseInt(agoraUid),
        'token': token,
        'appId': config.agora.appID
    }

    pusher.sendMessage(callee, payload)
});

module.exports = router;