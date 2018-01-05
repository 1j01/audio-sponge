
fs = require "fs"
SC = require "node-soundcloud"

clientID = process.env["soundcloud-client-id"] ? "99859bbbc016945344ec5ba5731400b4" # fs.readFileSync("soundcloud-client-id", "utf8")
accessToken = process.env["soundcloud-access-token"] ? try fs.readFileSync("soundcloud-access-token", "utf8")

server_port = process.env["PORT"] ? 3901
app_hostname = process.env["app-hostname"] ? "localhost"

app_origin = "http://#{app_hostname}:server_port"
soundcloud_callback_path = "/okay"
soundcloud_callback_url = "#{app_origin}#{soundcloud_callback_path}"

# Initialize client
console.log "init node-soundcloud"
SC.init
	id: clientID
	secret: process.env["soundcloud-api-secret"] ? fs.readFileSync("soundcloud-api.secret", "utf8")
	uri: soundcloud_callback_url #process.env["return-from-soundcloud-uri"] ? "http://localhost:#{server_port}/okay"
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
	fail = (message)->
		console.error "#{message}; querystring parameters:"
		console.error JSON.stringify req.query, null, 2
		body = """
			<!doctype html>
			<title>Sponge Error</title>
			<body>
				<p>#{message.replace(/&/g, "&").replace(/</g, "&lt;")}</p>
				<p><a href="/">retry?</a></p>
			</body>
		"""
		res.writeHead(500, {
			"Content-Type": "text/html",
			"Content-Length": Buffer.byteLength(body)
		})
		res.end(body)

	if req.query.error or req.query.error_description
		return fail "got error from soundcloud"
	unless req.query.code
		return fail "did not receive 'code' parameter from soundcloud"
	
	auth req.query.code, (err, accessToken)->
		return fail err.message if err
		
		console.log "got access token:", accessToken
		unless accessToken
			return fail "accessToken should not be #{accessToken}"
		
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

app.get soundcloud_callback_path, (req, res)->
	if accessToken
		res.redirect("/")
	else
		redirectHandler(req, res)

lame = require "lame"

Sponge = require "./Sponge"
StreamWrapper = require "./serve-stream"
Throttle = require "throttle"

stream_wrapper = null

start_stream = (error_callback)->
	sponge = new Sponge
	stream_wrapper = new StreamWrapper
	# console.log process.env.AUDIO_GLOB, process.env
	sponge.soak process.env.AUDIO_GLOB, (err)->
		return error_callback(err) if err
		sponge.squeeze (err, context)->
			return error_callback(err) if err
			
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
	error_callback = (err)->
		console.error err
		res.end("Internal server error: " + err.message)
		process.exit(1)
		# app.stop()
	if accessToken
		start_stream(error_callback) unless stream_wrapper
		stream_wrapper.stream(req, res)
	else
		res.redirect("/")

app.get "/ping", (req, res)->
	res.writeHead 200,
		"Cache-Control": "no-store, must-revalidate"
		"Expires": "0"
	res.end("pong")

app.listen server_port, ->
	console.log "listening on http://localhost:#{server_port}"
