
fs = require "fs"
SC = require "node-soundcloud"

get_required_env_var = (var_name)->
	return process.env[var_name] if process.env[var_name]?
	console.error("Environment variable #{var_name} required")

soundcloud_client_id = get_required_env_var "SOUNDCLOUD_CLIENT_ID"
soundcloud_api_secret = get_required_env_var "SOUNDCLOUD_API_SECRET"
soundcloud_access_token = get_required_env_var "SOUNDCLOUD_ACCESS_TOKEN"

audio_glob = get_required_env_var "AUDIO_SOURCE_FILES_GLOB"

server_port = process.env.PORT ? 3901
app_hostname = process.env.APP_HOSTNAME ? "localhost"

app_origin = "http://#{app_hostname}:#{server_port}"
soundcloud_auth_callback_path = "/okay"
soundcloud_auth_callback_url = "#{app_origin}#{soundcloud_auth_callback_path}"

# Initialize SoundCloud client
console.log "init node-soundcloud client"
SC.init
	id: soundcloud_client_id
	secret: soundcloud_api_secret
	uri: soundcloud_auth_callback_url
	accessToken: soundcloud_access_token

# Connect user to authorize application
initOAuth = (req, res)->
	res.redirect(SC.getConnectUrl())

auth = (code, callback)->
	if soundcloud_access_token
		console.log "reusing access token: #{soundcloud_access_token}"
		process.nextTick ->
			callback(null, soundcloud_access_token)
	else
		console.log "getting new access token for #{code}"
		SC.authorize code, (err, new_soundcloud_access_token)->
			soundcloud_access_token = new_soundcloud_access_token
			callback(err, soundcloud_access_token)

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
	
	auth req.query.code, (err, soundcloud_access_token)->
		return fail err.message if err
		
		console.log "got access token:", soundcloud_access_token
		unless soundcloud_access_token
			return fail "access token should not be #{soundcloud_access_token}"
		
		fs.writeFile "soundcloud-access-token", soundcloud_access_token, "utf8",
		
		res.redirect("/")

express = require "express"
app = express()

app.use(express.static("public"))

app.get "/", (req, res)->
	if soundcloud_access_token
		# SC.get "/me", (err, me)->
		# 	return console.error err if err
		# 	SC.get "/me/activities/tracks/affiliated", (err, data)->
		# 		return console.error err if err
		# 		tracks = (item.origin for item in data.collection)
		# 		res.render("index", {me, tracks, soundcloud_client_id: clientID})
		
		res.sendFile("index.html", root: __dirname)
	else
		initOAuth(req, res)

app.get soundcloud_auth_callback_path, (req, res)->
	if soundcloud_access_token
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
	sponge.soak audio_glob, (err)->
		return error_callback(err) if err
		sponge.squeeze (err, context)->
			return error_callback(err) if err
			
			# console.log context.format
			numberOfChannels = context.format.channels # context.format.numberOfChannels
			bytesPerSample = numberOfChannels * context.format.bitDepth / 8
			throttle =
				new Throttle
					bps: bytesPerSample * context.sampleRate
					chunkSize: bytesPerSample * 1024
			encoder =
				new lame.Encoder
					# input
					channels: numberOfChannels
					bitDepth: context.format.bitDepth
					sampleRate: context.sampleRate
					# output
					bitRate: 128
					outSampleRate: 22050
					mode: lame.STEREO # STEREO (default), JOINTSTEREO, DUALCHANNEL or MONO
			
			# throttle.addListener "data", (data)-> console.log data
			context.pipe(throttle)
			context.resume() # TODO: init stuff earlier and only resume() when a first client appears
			# and pause when there are no clients

			throttle
				.pipe(encoder)
				.pipe(stream_wrapper)

app.get "/stream", (req, res)->
	error_callback = (err)->
		console.error err
		res.end("Internal server error: " + err.message)
		process.exit(1)
		# app.stop()
	if soundcloud_access_token
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
	console.log "listening on #{app_origin}"
