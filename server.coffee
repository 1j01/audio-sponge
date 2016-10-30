
fs = require "fs"
SC = require "node-soundcloud"

clientID = "99859bbbc016945344ec5ba5731400b4" # fs.readFileSync("soundcloud-client-id", "utf8")
accessToken = try fs.readFileSync("soundcloud-access-token", "utf8")

# Initialize client
console.log "init node-soundcloud"
SC.init
	id: clientID
	secret: fs.readFileSync("soundcloud-api.secret", "utf8")
	uri: "http://localhost:3901/okay"
	accessToken: accessToken

# Connect user to authorize application
initOAuth = (req, res)->
	res.redirect(SC.getConnectUrl())

auth = (code, callback)->
	if accessToken
		console.log "reusing access token: #{accessToken}"
		process.nextTick ->
			callback(null, accessToken)
	else
		console.log "getting new access token for #{code}"
		SC.authorize code, (err, newAccessToken)->
			accessToken = newAccessToken
			callback(err, accessToken)

redirectHandler = (req, res)->
	auth req.query.code, (err, accessToken)->
		return console.error err if err
		console.log "got access token:", accessToken
		return console.error "accessToken should not be #{accessToken}" unless accessToken
		
		fs.writeFile "soundcloud-access-token", accessToken, "utf8",
		
		res.redirect("/")

express = require "express"
app = express()

app.use(express.static("public"))

app.get "/", (req, res)->
	if accessToken
		# SC.get "/me", (err, me)->
		# 	return console.error err if err
		# 	SC.get "/me/activities/tracks/affiliated", (err, data)->
		# 		return console.error err if err
		# 		tracks = (item.origin for item in data.collection)
		# 		res.render("index", {me, tracks, client_id: clientID})
		
		res.sendFile("index.html", root: __dirname)
	else
		initOAuth(req, res)

app.get "/okay", (req, res)->
	if accessToken
		res.redirect("/")
	else
		redirectHandler(req, res)

lame = require "lame"

Sponge = require "./Sponge"
StreamWrapper = require "./serve-stream"
Throttle = require "throttle"

stream_wrapper = null

start_stream = ->
	sponge = new Sponge
	stream_wrapper = new StreamWrapper
	sponge.soak process.env.AUDIO_GLOB, ->
		context = sponge.squeeze()
		bytesPerSample = context.format.numberOfChannels * context.format.bitDepth / 8
		throttle =
			new Throttle
				bps: bytesPerSample * context.sampleRate
				chunkSize: bytesPerSample * 1024
		encoder =
			new lame.Encoder
				# input
				channels: context.format.numberOfChannels
				bitDepth: context.format.bitDepth
				sampleRate: context.sampleRate
				# output
				bitRate: 128
				outSampleRate: 22050
				mode: lame.STEREO # STEREO (default), JOINTSTEREO, DUALCHANNEL or MONO
		
		context.outStream = throttle
		throttle
			.pipe(encoder)
			.pipe(stream_wrapper)

app.get "/stream", (req, res)->
	if accessToken
		start_stream() unless stream_wrapper
		stream_wrapper.stream(req, res)
	else
		res.redirect("/")

app.get "/ping", (req, res)->
	res.writeHead 200,
		"Cache-Control": "no-store, must-revalidate"
		"Expires": "0"
	res.end("pong")

app.listen 3901, ->
	console.log "listening on http://localhost:3901"
