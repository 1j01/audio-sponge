fs = require "fs"
SC = require "node-soundcloud"
# sc_searcher = require "soundcloud-searcher"
get_env_var = require "./get-env-var"

# TODO: uppercase these (constant but not const) variable names
soundcloud_client_id = get_env_var "SOUNDCLOUD_CLIENT_ID", required: yes
soundcloud_api_secret = get_env_var "SOUNDCLOUD_API_SECRET", required: yes
soundcloud_access_token = get_env_var "SOUNDCLOUD_ACCESS_TOKEN", required: yes

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"


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

# TODO: probably remove ALL THE OAUTH STUFF
# and use https://www.npmjs.com/package/simple-soundcloud
# or similar

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
		res.sendFile("public/app.html", root: __dirname + "/..")
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

sponge = new Sponge
stream_wrapper = new StreamWrapper

sponge.start (err, context)->
	if err
		console.error err
		console.log "The server will exit shortly."
		setTimeout ->
			process.exit(1)
		, 200
		# TODO: exit more cleanly? like end the server and such
	
	# Note: inconsistent naming between web-audio-api and web-audio-engine for numberOfChannels/channels
	numberOfChannels = context.format.channels
	bytesPerSample = numberOfChannels * context.format.bitDepth / 8
	throttle =
		new Throttle
			bps: bytesPerSample * context.sampleRate
			chunkSize: bytesPerSample * 1024 # TODO: use blockSize from context?
	encoder =
		new lame.Encoder
			# input options
			channels: numberOfChannels
			bitDepth: context.format.bitDepth
			sampleRate: context.sampleRate
			# output options
			bitRate: 128
			outSampleRate: 22050
			mode: lame.STEREO # STEREO (default), JOINTSTEREO, DUALCHANNEL or MONO
	
	context.pipe(throttle)

	throttle
		.pipe(encoder)
		.pipe(stream_wrapper)
	
	# TODO: buffer a bit of audio to burst / to the client that's first.. to quench their thirst
	# (having to wait is like the wooorst / it makes you feel.. like ur cursed)
	# TODO: log when clients leave
	setInterval =>
		if stream_wrapper.clients.length > 0
			unless context._isPlaying
				console.log "#{stream_wrapper.clients.length} client(s), resume"
				context.resume()
		else
			if context._isPlaying
				console.log "no clients, pausing"
				context.suspend()
	, 200

app.get "/stream", (req, res)->
	if soundcloud_access_token
		stream_wrapper.stream(req, res)
	else
		res.redirect("/")

app.get "/attribution", (req, res)->
	# TODO: are these setHeaders needed?
	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	# TODO: eventually drop sources, so that this list doesn't get ridiculous
	res.json({
		sources:
			for source in sponge.sources
				# {link, name} = source.metadata
				# {link, name}
				source.metadata
	})

app.get "/ping", (req, res)->
	res.writeHead 200,
		"Cache-Control": "no-store, must-revalidate"
		"Expires": "0"
	res.end("pong")

app.listen server_port, ->
	console.log ""
	console.log ".--------------------------------------------------- - - -"
	console.log "| listening on #{app_origin}"
	console.log "'--------------------------------------------------- - - -"
	console.log ""
